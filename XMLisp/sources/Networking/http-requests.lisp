(in-package :ccl)


(defun PARSE-URL (Url) "
  in:  URL {URL}.
  out: Server Port File {string}.
  Parse an URL into <server> <port> and <file>. If no port provided, default is 80
  e.g, ''http://www.cs.colorado.edu/homes/ralex/public_html/Home.html''
  => server = www.cs.colorado.edu
  => file   = /homes/ralex/public_html/Home.html."
  (let ((Start (search "//" URL)))
    (when Start
      (let* ((String (subseq URL (+ Start 2)))
             (File-Index (search "/" String)))
        (when File-Index
          (let* ((Server (subseq String 0 File-index))
                 (File (subseq String File-index))
                 (Colon-Position (search ":" server))
                 (Port 80))
            (when colon-position 
              (setq Port (read-from-string (subseq Server (1+ colon-position))))
              (setq Server (subseq Server 0 colon-position)))
            (values
             server
             port
             file)))))))


(defun ENCODE-WEB-STRING (String) "
  in:  String {string}.
  out: String {string}.
  Convert the string to a format acceptable for transmission with an HTTP
  POST query.  Spaces are converted to the '+' character and non-alphanumerics
  are converted to their hexadecimal equivalents as '%xx'."
  (unless (stringp String)
    (setq String (write-to-string String)))
  (let ((Current-Char nil))
    (with-input-from-string (Input-String String)
      (with-output-to-string (Output-String)
        (loop
          (setq Current-Char (read-char Input-String nil nil))
          (when (null Current-Char) (return))
          (if (and (standard-char-p Current-Char)
                   (or (alpha-char-p Current-Char)
                       (digit-char-p Current-Char)))
            (write-char Current-Char Output-String)
            (if (char= Current-Char #\Space)
              (write-char #\+ Output-String)
              (format Output-String "%~2,'0X" (char-code Current-Char)))))))))


(defun ENCODE-ASSOC (Pairs) "
  in:  Pairs {assoc}.
  out:  String {string}.
  Takes the association list and creates an HTTP post query.  For each key-value
  pair, a HTTP compatible key=value pair is generated."
  (let ((Current-Key nil)
        (Current-Value nil))
    ;; Remove the trailing ampersand
    (string-right-trim
     "&"
     (with-output-to-string (Output-String)
       (dolist (Current-Entry Pairs)
         (setq Current-Key (first Current-Entry))
         (setq Current-Value (second Current-Entry))
         (format Output-String "~A=~A&"
                 (encode-web-string (symbol-name Current-Key))
                 (encode-web-string Current-Value)))))))


;***********************************
;    HTTP-REQUEST                  *
;***********************************

(defclass HTTP-REQUEST ()
  ((http-protocol :accessor http-protocol :initarg :http-protocol :initform 1.1)
   (host :accessor host :initarg :host :initform nil)
   (port :accessor port :initarg :port :initform nil)
   (path-to-web-page :accessor path-to-web-page :initarg :path-to-web-page :initform nil))
  (:documentation "the base class for http requests"))


(defgeneric HTTP-COMMAND (Http-Request Stream)
  (:documentation "implemented by the specific http-request: returns the http command to be issued"))


(defmethod ISSUE-HTTP-REQUEST ((Self http-request))
  (with-open-socket (Stream :remote-host (host Self)
                            :remote-port (port Self))
    ;; issue the command
    (http-command Self Stream)
    ;; get and (for now) print response
    (let ((Char))
      (with-output-to-string (Response)
        (loop 
          (setq Char (or (read-char Stream nil nil) (return)))
          (princ Char Response))))))



;***********************************
;    HTTP-GET-REQUEST              *
;***********************************

(defclass HTTP-GET-REQUEST (http-request)
  ((key-value-pairs :accessor key-value-pairs :initarg :key-value-pairs :initform nil)))


(defmethod HTTP-COMMAND ((Self http-get-request) Stream)
  (write-string
   (format nil "GET ~A HTTP/~A~C~CHost: ~A~A~C~C~C~C"
                  (path-to-web-page Self)
                  (http-protocol Self)
                  #\Return #\Linefeed
                  (host Self)
                  (if (port Self)
                    (format nil ":~A" (port Self))
                    "")
                  #\Return #\Linefeed #\Return #\Linefeed)  ;; end of header
   Stream)
  (force-output Stream))


(defun HTTP-GET (Url)
  (multiple-value-bind (Server Port Path-To-Web-Page)
                       (parse-url Url)
      (issue-http-request (make-instance 'http-get-request
                            :http-protocol 1.1
                            :host Server
                            :port Port
                            :path-to-web-page Path-To-Web-Page))))


#| Examples

(http-get "http://199.45.162.69:8000/agentsheets-distribution/register-mac-intel")
(http-get "http://199.45.162.69:8000/upload-to-arcade?project-name=TEST123&project-author=Andri&zip-file=zip+data+to+come")

|#



;***********************************
;    HTTP-POST-REQUEST             *
;***********************************

(defclass HTTP-POST-REQUEST (http-request)
  ((content :accessor content :initarg :content :initform nil)
   (content-type :accessor content-type :initarg :content-type :initform nil)
   (content-length :accessor content-length :initarg :content-length :initform nil)))


(defmethod HTTP-COMMAND ((Self http-post-request) Stream)
  (let ((Content (content Self)))
    (write-string (format nil "~A~A~A~A~A"
                                 (format nil "POST ~A HTTP/~A~C~CHost: ~A~A~C~C"
                                         (path-to-web-page Self)
                                         (http-protocol Self)
                                         #\Return #\Linefeed
                                         (host Self)
                                         (if (port Self)
                                           (format nil ":~A" (port Self))
                                           "")
                                         #\Return #\Linefeed)
                                 (format nil "Content-type: ~A~C~C" (content-type Self) #\Return #\Linefeed)
                                 (format nil "Content-length: ~A~C~C" (content-length Self) #\Return #\Linefeed)
                                 (format nil "~C~C" #\Return #\Linefeed)
                                 (format nil "~A~C~C" Content #\Return #\Linefeed))
                         Stream)
    (force-output Stream)))


;---------------------------
; Form                    /
;-------------------------

(defclass HTTP-URLENCODED-FORM-REQUEST (http-post-request)
  ((fields :accessor fields :initarg :fields :initform nil))
  (:documentation ""))


(defmethod CONTENT ((Self http-urlencoded-form-request))
  (let ((Data (encode-assoc (fields Self))))
    (set-slot-value Self 'content Data)
    Data))


(defmethod CONTENT-TYPE ((Self http-urlencoded-form-request))
  "application/x-www-form-urlencoded")


(defmethod CONTENT-LENGTH ((Self http-urlencoded-form-request))
  (length (slot-value Self 'content)))


;---------------------------
; File                    /
;-------------------------

;; need a file post request ???
(defclass HTTP-FILE-REQUEST (http-post-request)
  ((file :accessor file :initarg :file :initform nil)
   (file-type :accessor file-type :initarg :file-type :initform "file")
   (file-transfer-encoding :accessor file-transfer-encoding :initarg :file-transfer-encoding :initform "binary"))
  (:documentation ""))


;---------------------------
; Multi-part Form         /
;-------------------------

(defclass HTTP-MULTIPART-FORM-REQUEST (http-urlencoded-form-request http-file-request)
  ((boundary :accessor boundary :initarg :boundary :initform "AaB03x")
   (file-field-name :accessor file-field-name :initarg :file-field-name :initform "file"))
  (:documentation ""))


(defmethod CONTENT ((Self http-multipart-form-request))
  (let ((Data)
        (Form-Data)
        (File-Data (with-open-file (File (file Self)
                                         :direction :input
                                         :if-does-not-exist :error)
                     (with-output-to-string (Data-Read)
                       (loop 
                         (princ (or (read-char File nil nil) (return)) Data-Read))))))
    (dolist (Field (fields Self))
      (setq Form-Data (concatenate 'string Form-Data
                              (format nil "--~A~C~Ccontent-disposition: form-data; name=\"~A\"~C~C~C~C~A~C~C" 
                                      (boundary Self)
                                      #\Return #\Linefeed
                                      (first field)
                                      #\Return #\Linefeed #\Return #\Linefeed
                                      (second Field)
                                      #\Return #\Linefeed))))
    (setq Data (format nil "~A~A"
                       Form-Data
                       (format nil "--~A~C~Ccontent-disposition: form-data; name=\"~A\"; filename=\"~A.~A\"~C~CContent-Type: ~A~C~CContent-Transfer-Encoding: ~A~C~C~C~C~A~C~C--~A--"
                               (boundary Self)
                               #\Return #\Linefeed
                               (file-field-name Self)
                               (pathname-name (file Self))
                               (pathname-type (file Self))
                               #\Return #\Linefeed
                               (file-type Self)
                               #\Return #\Linefeed
                               (file-transfer-encoding Self)
                               #\Return #\Linefeed #\Return #\Linefeed
                               File-Data
                               #\Return #\Linefeed
                               (boundary Self))))
    (set-slot-value Self 'content Data)
    Data))


(defmethod CONTENT-TYPE ((Self http-multipart-form-request))
  (format nil "multipart/form-data, boundary=~A" (boundary Self)))


(defun HTTP-POST (Url &key fields file file-type file-field-name)
  (multiple-value-bind (Server Port Path-to-web-page)
                       (parse-url Url)
    (let ((Post-Request (cond ((and fields file)
                               (make-instance 'http-multipart-form-request
                                 :http-protocol 1.1
                                 :host Server
                                 :port Port
                                 :path-to-web-page Path-To-Web-Page
                                 :fields Fields
                                 :file File
                                 :file-type File-type
                                 :file-field-name File-Field-Name))
                              (t (make-instance 'http-urlencoded-form-request
                                   :http-protocol 1.1
                                   :host Server
                                   :port Port
                                   :path-to-web-page Path-To-Web-Page
                                   :fields fields)))))
      (issue-http-request Post-Request))))



#| Examples 

(defparameter Zip-File "/Users/andri/Desktop/testupload arcade file.zip")

(http-post "http://scalablegamedesign.cs.colorado.edu/sgda/acarcade/acsubmission.php?"
           :fields '((id "agentcubes") (pass "actesting")))

(http-post "http://scalablegamedesign.cs.colorado.edu/sgda/acarcade/acsubmission.php?"
           :fields '((id "agentcubes") (pass "actesting"))
           :file Zip-File
           :file-field-name "UFILE"
           :file-type "application/zip")


(defparameter r (make-instance 'http-multipart-form-request
                  :fields '((id "agentcubes") (pass "actesting"))
                  :file Zip-File
                  :file-field-name "UFILE"
                  :file-type "application/zip"))
(content r)
(content-type r)
(content-length r)

|#