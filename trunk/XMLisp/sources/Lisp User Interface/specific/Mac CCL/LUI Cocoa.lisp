;;; MAC CCL Windoinvow
;;; LUI: Lisp User Interface
;;; Andri Ioannidou and Alexander Repenning
;;; Version: 0.2 11/28/08
;;;          0.3 03/12/09 CCL 1.3: do not rely on NSstring auto conversion
;;;          0.3.1 04/27/09 Raffael Cavallaro, raffaelcavallaro@mac.com web-browser-control fixed
;;;          0.4   05/30/09 Full Screen Mode
;;;          0.4.1 02/19/10 add-subviews and add-subview for scroll-view: only allow one subview; fixed map-subiews for scroll-view
;;;          0.4.2 03/15/10 AI file->source for image-control

(in-package :LUI)


#-cocotron
(eval-when (:compile-toplevel :load-toplevel :execute)
  (ccl:use-interface-dir :carbon) 
  (open-shared-library "/System/Library/Frameworks/Carbon.framework/Carbon"))

;;*********************************
;; Native -> LUI name converters  *
;;*********************************

(defmethod NATIVE-TO-LUI-EVENT-TYPE (NS-Type)
  (case NS-Type
    (#.#$NSLeftMouseDown :left-mouse-down)
    (#.#$NSLeftMouseUp :left-mouse-up)
    (#.#$NSRightMouseDown :right-mouse-down)
    (#.#$NSRightMouseUp :right-mouse-up)
    #-cocotron (#.#$NSOtherMouseDown :other-mouse-down)
    #-cocotron (#.#$NSOtherMouseUp :other-mouse-up)
    (#.#$NSMouseMoved :mouse-moved)
    (#.#$NSLeftMouseDragged :left-mouse-dragged)
    (#.#$NSRightMouseDragged :right-mouse-dragged)
    #-cocotron (#.#$NSOtherMouseDragged :other-mouse-dragged)
    (#.#$NSMouseEntered :mouse-entered)
    (#.#$NSMouseExited :mouse-exited)
    (#.#$NSKeyDown :key-down)
    (#.#$NSKeyUp :key-up)
    (#.#$NSFlagsChanged :flags-changed)
    #-cocotron (#.#$NSAppKitDefined :app-kit-defined)
    #-cocotron (#.#$NSSystemDefined :system-defined)
    (#.#$NSApplicationDefined :application-defined)
    (#.#$NSPeriodic :periodic)
    (#.#$NSCursorUpdate :cursor-update)
    (#.#$NSScrollWheel :scroll-wheel)
    (t :undefined-event)))

;;*********************************
;; user defined System parameters *
;;*********************************

(defvar *System-Selection-Color*
  #-cocotron
  (let ((Color (#/colorUsingColorSpaceName: 
                (#/selectedTextBackgroundColor ns::ns-color)
                #@"NSCalibratedRGBColorSpace")))
    (list (float (#/redComponent Color) 0.0) (float (#/greenComponent Color) 0.0) (float (#/blueComponent Color) 0.0)))
  ;; Cocotron doesn't implement #@"NSCalibratedRGBColorSpace" nor #/redComponent, etc.
  #+cocotron (list 0.654139 0.793225 0.9990845)
  "system color defined by user used for selections, e.g., selected text background color")

;;*********************************
;; Native -> LUI Coordinates      *
;;*********************************

(defmethod LUI-SCREEN-COORDINATE (x y)
  (values
   x
   (truncate (- (pref (#/frame (#/mainScreen ns:ns-screen)) <NSR>ect.size.height) y)))) 

;;*********************************
;; Native Strings                 *
;;*********************************

(defun NATIVE-STRING (String) "
  Return a native string"
  (#/autorelease (ccl::%make-nsstring String)))

;**********************************
;* EVENT                          *
;**********************************

(defmethod COMMAND-KEY-P ()
  (let ((current-event (#/currentEvent (#/sharedApplication ns:ns-application))))
    (not (zerop (logand (#/modifierFlags current-event) #$NSCommandKeyMask)))))



(defmethod ALT-KEY-P ()
  (let ((current-event (#/currentEvent (#/sharedApplication ns:ns-application))))
    (not (zerop (logand (#/modifierFlags current-event) #$NSAlternateKeyMask)))))


(defmethod SHIFT-KEY-P ()
  (let ((current-event (#/currentEvent (#/sharedApplication ns:ns-application))))
    (not (zerop (logand (#/modifierFlags current-event) #$NSShiftKeyMask)))))
    

(defmethod CONTROL-KEY-P ()
  (let ((current-event (#/currentEvent (#/sharedApplication ns:ns-application))))
    (not (zerop (logand (#/modifierFlags current-event) #$NSControlKeyMask)))))



(defmethod DOUBLE-CLICK-P ()
  (when *Current-Event*
    (= (#/clickCount (native-event *Current-Event*)) 2)))


;;*********************************
;; Mouse Polling                  *
;;*********************************

(defun MOUSE-LOCATION () "
  out: x y 
  Return screen coordinates of the current mouse location"
  (let ((Location (#/mouseLocation ns:ns-event)))
    (values
     (truncate (pref Location :<NSP>oint.x))
     (truncate (- (screen-height nil) (pref Location :<NSP>oint.y))))))

;(mouse-location)

;**********************************
;* SUBVIEW-MANAGER-INTERFACE      *
;**********************************

(defmethod ADD-SUBVIEW ((View subview-manager-interface) (Subview subview-manager-interface))
  (#/addSubview: (native-view View) (native-view Subview))
  (setf (part-of Subview) View))
  

(defmethod ADD-SUBVIEWS ((Self subview-manager-interface) &rest Subviews)
  (dolist (Subview Subviews)
    (add-subview Self Subview)))


(defmethod SWAP-SUBVIEW ((View subview-manager-interface) (Old-Subview subview-manager-interface) (New-Subview subview-manager-interface))
  ;; make compatible: new and old compatible with respect to size and origin
  (set-size New-Subview (width Old-Subview) (height Old-Subview))
  ;; adjust structure
  (#/retain (native-view Old-Subview)) ;; no GC
  (#/replaceSubview:with: (native-view View) (native-view Old-Subview) (native-view New-Subview))
  (setf (part-of New-Subview) View)
  ;; set size again to give views such as opengl views a chance to reestablish themselves
  (set-size New-Subview (width Old-Subview) (height Old-Subview)))
  


(defmethod MAP-SUBVIEWS ((Self subview-manager-interface) Function &rest Args)
  (let ((Subviews (#/subviews (native-view Self))))
    (dotimes (i (#/count Subviews))
      
      (apply Function (lui-view (#/objectAtIndex: Subviews i)) Args))))


(defmethod SUBVIEWS ((Self subview-manager-interface))
  (when (native-view Self)              ;Allows tracing MAKE-NATIVE-OBJECT
    (let* ((Subviews (#/subviews (native-view Self)))
           (Count (#/count Subviews))
           (Subview-List nil))
      (dotimes (i Count Subview-List)
        (push (lui-view (#/objectAtIndex: Subviews (- Count 1 i))) Subview-List)))))


(defmethod SUPERVIEW ((Self subview-manager-interface))
  (let ((Superview (#/superview (native-view Self))))
    (and (not (%null-ptr-p Superview))
         (slot-exists-p Superview 'lui-view)
         (lui-view Superview))))

;**********************************
;* Control                        *
;**********************************

(defmethod DISABLE ((Self control))
  (#/setEnabled: (native-view self) #$NO))

(defmethod ENABLE ((Self control))
  (#/setEnabled: (native-view self) #$YES))

;**********************************
;* VIEW                           *
;**********************************

(defmethod SET-FRAME ((Self view) &key x y width height)
  (setf (x Self) (or x (x Self)))
  (setf (y Self) (or y (y Self)))
  (setf (width Self) (or width (width Self)))
  (setf (height Self) (or height (height Self)))
  (ns:with-ns-rect (Frame (x Self) (y Self) (width Self) (height Self))
    (#/setFrame: (native-view Self) Frame)))


(defmethod SET-SIZE :after ((Self view) Width Height)
  (ns:with-ns-size (Size Width Height)
    (#/setFrameSize: (native-view Self) Size)))


(defmethod SET-POSITION :after ((Self view) X Y)
  (ns:with-ns-point (Point X Y)
    (#/setFrameOrigin: (native-view Self) Point)))


(defmethod MAKE-NATIVE-OBJECT ((Self view))
  (let ((View (make-instance 'native-view :lui-view Self)))
    (ns:with-ns-rect (Frame (x Self) (y Self) (width Self) (height Self))
      (#/setFrame: View Frame))
    View))


(defmethod SWAP-SUBVIEW ((View view) (Old-Subview view) (New-Subview view))
  ;; (#/disableScreenUpdatesUntilFlush (native-window (window View)))
  ;; make compatible: new and old compatible with respect to size and origin
  (setf (x New-Subview) (x Old-Subview))
  (setf (y New-Subview) (y Old-Subview))
  (set-size New-Subview (width Old-Subview) (height Old-Subview))
  (#/setFrame: (native-view New-Subview) (#/frame (native-view Old-Subview)))
  ;; adjust structure
  (#/retain (native-view Old-Subview)) ;; no GC
  (#/replaceSubview:with: (native-view View) (native-view Old-Subview) (native-view New-Subview))
  (setf (part-of New-Subview) View)
  (subviews-swapped (window View) Old-Subview New-Subview)
  ;; (#/flushWindow (native-window (window View)))
  )


(defmethod WINDOW ((Self view))
  (lui-window (#/window (native-view Self))))


(defmethod DISPLAY ((Self view))
  ;; will not work without flushing window
  (#/display (native-view Self)))


(defmethod ADD-TRACKING-RECT ((Self view))
  (print "ADD TRACKING RECT")
  (print (#/frame (native-view self)))
  (print (NS:NS-RECT-HEIGHT (#/frame (native-view self))))
  (#/addTrackingRect:owner:userData:assumeInside: 
   (native-view self)
   (#/frame (native-view self))
   (native-view self)
   +null-ptr+
   #$NO))


;__________________________________
; NATIVE-VIEW                      |
;__________________________________/

(defclass NATIVE-VIEW (ns:ns-view)
  ((lui-view :accessor lui-view :initform nil :initarg :lui-view))
  (:metaclass ns:+ns-object
	      :documentation "the native NSView associated with the LUI view"))


(objc:defmethod (#/drawRect: :void) ((self native-view) (rect :<NSR>ect))
  ;; if there is an error make this restartable from alternate console
  (with-simple-restart (abandon-drawing "Stop trying Cocoa to draw in ~s" Self)
    (draw (lui-view Self))))


(objc:defmethod (#/display :void) ((self native-view))
  ;; (format t "~%display simple view")
  )


(objc:defmethod (#/isFlipped :<BOOL>) ((self native-view))
  ;; Flip to coordinate system to 0, 0 = upper left corner
  #$YES)





;**********************************
;* SCROLL-VIEW                    *
;**********************************

(defclass NATIVE-SCROLL-VIEW (ns:ns-scroll-view)
  ((lui-view :accessor lui-view :initform nil :initarg :lui-view))
  (:metaclass ns:+ns-object
	      :documentation "the native NSScrollView associated with the LUI view"))


(defmethod make-native-object ((Self scroll-view))
  (let ((Native-Control (make-instance 'native-scroll-view :lui-view Self)))
    (ns:with-ns-rect (Frame (x self) (y Self) (width Self) (height Self))
      (#/initWithFrame: Native-Control Frame)
      (#/setHasHorizontalScroller: Native-Control (has-horizontal-scroller Self))
      (#/setHasVerticalScroller: Native-Control (has-vertical-scroller Self))
      #-cocotron (#/setAutohidesScrollers: Native-Control #$YES)
      (#/setBorderType: Native-Control #$NSNoBorder)  ;;; #$NSLineBorder)
      (#/setDrawsBackground: Native-Control #$NO)
    Native-Control)))


(defmethod ADD-SUBVIEWS ((view scroll-view)  &rest Subviews)
  (call-next-method)
  ;; it only really makes sense to have one subview
  (#/setDocumentView: (native-view View) (native-view (first Subviews)))
  ;(warn "You are adding multiple views to a scroll-view. Only the first one will be visible.")
  )


(defmethod ADD-SUBVIEW ((view scroll-view)  Subview)
  (call-next-method)
  (unless (%null-ptr-p (#/documentView (native-view View))) 
    (warn "Redefining document view of scroll view. Only one subview is allowed in a scroll view."))
  ;; make it the document view
  (#/setDocumentView: (native-view View) (native-view Subview)))


(defmethod MAP-SUBVIEWS ((Self scroll-view) Function &rest Args)
  ;; no digging: only apply to document view
  (let ((Document-View (#/documentView (native-view Self))))
    ;; can't use (when Document-View) -- empty document view is a null pointer 
    (unless (%null-ptr-p Document-View) 
      (apply Function (lui-view Document-View) Args))))


(defmethod SET-SIZE ((Self scroll-view) W H)
  (declare (ignore W H))
  (call-next-method)
  ;;  (format t "~%size ~A, ~A" W H)
  ;; need to propagate sizing to subviews: not likely to effect their sizes but needs to be done at least once
  (map-subviews Self #'(lambda (View) (set-size View (width View) (height View)))))


(defmethod SET-SIZE-ONCE ((Self scroll-view) W H)
  (declare (ignore W H))
  ;;  (format t "~%size ~A, ~A" W H)
  ;; need to propagate sizing to subviews: not likely to effect their sizes but needs to be done at least once
  (map-subviews Self #'(lambda (View) (set-size View (width View) (height View)))))
      


;**********************************
;* SCROLL-VIEW-ADJUSTING-CONTENTS *
;**********************************

(defmethod SET-SIZE ((Self scroll-view-adjusting-contents) W H)
  (declare (ignore W H))
  (call-next-method)
  ;; set width of subviews to be the width of the scroll-view minus the vertical scroller width, if present
  (map-subviews Self #'(lambda (View) (set-size View 
                                                (ns::ns-size-width (#/contentSize (native-view Self)))
                                                (height View)))))



;**********************************
;* RECTANGLE-VIEW                 *
;**********************************

(defmethod SET-COLOR ((Self rectangle-view) &key (Red 0.0) (Green 0.0) (Blue 0.0) (Alpha 1.0))
  ;; keep a native color instead of creating a new one for each display
  (when (native-color Self) (#/release (native-color Self)))
  (setf (native-color Self) (#/colorWithCalibratedRed:green:blue:alpha: ns:ns-color Red Green Blue Alpha))
  (#/retain (native-color Self)))


(defmethod DRAW ((Self rectangle-view))
  (when (native-color Self)
    (#/set (native-color Self)))
  (ns:with-ns-rect (Frame 0.0 0.0 (width Self) (height Self))
    (#_NSRectFill Frame)))

;;************************************
;; WINDOW                            *
;;************************************

(defmethod WINDOW-CLOSE ((Self Window))
  (#/close (native-window Self)))


;__________________________________
; NATIVE-WINDOW                     |
;__________________________________/

(defclass NATIVE-WINDOW (ns:ns-window)
  ((lui-window :accessor lui-window :initarg :lui-window)
   (delegate :accessor delegate :initform nil :initarg :delegate :documentation "event delegate"))
  (:metaclass ns:+ns-object
	      :documentation "Native window"))


(objc:defmethod (#/sendEvent: :void) ((Self native-window) Event)
  ;; (print (native-to-lui-event-type (#/type Event)))
  (call-next-method Event))


(objc:defmethod (#/mouseMoved: :void) ((self native-window) Event)
  (let ((mouse-loc (#/locationInWindow event)))
    (view-event-handler (lui-window Self) 
                        (make-instance 'mouse-event
                          :x (truncate (pref mouse-loc :<NSP>oint.x))
                          :y (truncate (- (height (lui-window Self)) (pref mouse-loc :<NSP>oint.y)))
                          :dx (truncate (#/deltaX Event))
                          :dy (truncate (#/deltaY Event))
                          :event-type (native-to-lui-event-type (#/type event))
                          :native-event Event))))


(objc:defmethod (#/keyDown: :void) ((self native-window) event)
  (call-next-method event)
  (view-event-handler (lui-window Self)
                      (make-instance 'key-event 
                        :key-code (#/keyCode Event)
                        :event-type (native-to-lui-event-type (#/type event))
                        :native-event Event)))

#|
(objc:defmethod (#/flagsChanged: :void) ((self native-window) event)
  (view-event-handler (lui-window Self)
                      (make-instance 'key-event 
                        :key-code (#/keyCode Event)
                        :event-type (native-to-lui-event-type (#/type event))
                        :native-event Event)))
|#

(objc:defmethod (#/becomeMainWindow :void) ((self native-window))
  (call-next-method)
  (has-become-main-window (lui-window Self)))


(objc:defmethod (#/constrainFrameRect:toScreen: :<NSR>ect) ((Self native-window) (Rect :<NSR>ect) Screen)
  (declare (ignore Screen))
  ;; a nasty hack to be able move windows above the menu bar
  (if (full-screen (lui-window Self))
    (let ((Window-Title-Bar-Height 22))
      (ns:make-ns-rect 
       0
       0
       (pref (#/frame (#/screen Self)) <NSR>ect.size.width)
       (+ (pref (#/frame (#/screen Self)) <NSR>ect.size.height) Window-Title-Bar-Height)))
    Rect))


#| 
(objc:defmethod (#/displayIfNeeded :void) ((Self native-window))
  (call-next-method)
  (display (lui-window Self))
  (print "displayIfNeeded"))

|#

;__________________________________
; Window-delegate                   |
;__________________________________/

(defclass WINDOW-DELEGATE (ns:ns-object)
  ((lui-window :accessor lui-window :initarg :lui-window))
  (:metaclass ns:+ns-object
	      :documentation "delegate object receiving window events"))


(objc:defmethod (#/windowDidResize: :void) ((self window-delegate) Notification)
  (declare (ignore Notification))
  ;; only the size of the content view
  (let ((Content-View (#/contentView (native-window (lui-window Self)))))
    (setf (width (lui-window Self)) (truncate (pref (#/frame Content-View) <NSR>ect.size.width)))
    (setf (height (lui-window Self)) (truncate (pref (#/frame Content-View) <NSR>ect.size.height)))
    (size-changed-event-handler (lui-window Self) (width (lui-window Self)) (height (lui-window Self)))))


(objc:defmethod (#/windowWillClose: :void) ((self window-delegate) Notification)
  (window-will-close (lui-window self) Notification))


(objc:defmethod (#/windowShouldClose: :<BOOL>) ((self window-delegate) Sender)
  (declare (ignore Sender))
  (if (window-should-close (lui-window self))
    #$YES
    #$NO))

#|
(objc:defmethod (#/windowDidEndLiveResize: :void) ((self window-delegate) Notification)
  (print "-------------DID END LIVE RESIZE-------------")
  (call-next-method)
  )
|#

(objc:defmethod (#/windowDidMove: :void) ((self window-delegate) Notification)
  (declare (ignore Notification))
  (let ((Window (lui-window Self)))
    (setf (x Window) (truncate (pref (#/frame (native-window (lui-window Self))) <NSR>ect.origin.x)))
    (setf (y Window) 
          (- (screen-height (lui-window Self)) 
             (height (lui-window Self))
             (truncate (pref (#/frame (native-window (lui-window Self))) <NSR>ect.origin.y))))))

;__________________________________
; window methods                   |
;__________________________________/

(defmacro IN-MAIN-THREAD (() &body body)
  (let ((thunk (gensym))
        (done (gensym))
        (result (gensym)))
    `(let ((,done nil)
           (,result nil))
       (flet ((,thunk ()
                (setq ,result (multiple-value-list (progn ,@body))
                      ,done t)))
         (gui::execute-in-gui #',thunk)
         (process-wait "Main thread" #'(lambda () ,done))
         (values-list ,result)))))


(defmethod MAKE-NATIVE-OBJECT ((Self window))
  (in-main-thread ()
    (ccl::with-autorelease-pool
      (let ((Window (make-instance 'native-window
                        :lui-window Self
                        :with-content-rect (ns:make-ns-rect 0 0 (width Self) (height Self))
                        :style-mask (if (borderless Self)
                                      0
                                      (logior (if (title Self) #$NSTitledWindowMask 0)
                                              (if (closeable Self) #$NSClosableWindowMask 0)
                                              (if (resizable Self) #$NSResizableWindowMask 0)
                                              (if (minimizable Self) #$NSMiniaturizableWindowMask 0)))
                        :backing #$NSBackingStoreBuffered
                        :defer t)))
        (#/disableCursorRects Window) ;; HACK: http://www.mail-archive.com/cocoa-dev@lists.apple.com/msg27510.html
        (setf (native-window Self) Window)  ;; need to have this reference for the delegate to be in place
        (setf (native-view Self) (make-instance 'native-window-view :lui-window Self))
        ;; setup delegate
        (setf (delegate Window) (make-instance 'window-delegate :lui-window Self))
        (#/setDelegate: Window (delegate Window))
        ;; content view
        (#/setContentView: Window (#/autorelease (native-view Self)))
        (#/setTitle: Window (native-string (title Self)))
        (ns:with-ns-size (Position (x Self) (- (screen-height Self)  (y Self)))
          (#/setFrameTopLeftPoint: (native-window Self) Position))
        (when (track-mouse Self) (#/setAcceptsMouseMovedEvents: (native-window Self) #$YES))
        Window))))


(defmethod DISPLAY ((Self window))
  ;; excessive?  
  (in-main-thread ()
    (#/display (native-view Self))))


(defmethod SET-SIZE :after ((Self window) Width Height)
  (ns:with-ns-size (Size Width Height)
    (#/setContentSize: (native-window Self) Size)))


(defmethod SET-POSITION :after ((Self window) x y)
  (ns:with-ns-size (Position x (- (screen-height Self)  y))
    (#/setFrameTopLeftPoint: (native-window Self) Position)))


(defmethod SHOW ((Self window))
  (in-main-thread ()
    ;; (let ((y (truncate (- (pref (#/frame (#/mainScreen ns:ns-screen)) <NSR>ect.size.height) (y Self) (height Self)))))
    ;;   (ns:with-ns-rect (Frame (x Self) y (width Self) (height Self))
    ;;   (#/setFrame:display: (native-window Self) Frame t)))
    (#/orderFront: (native-window Self) nil)
    (#/makeKeyWindow (native-window self))))


(defmethod HIDE ((Self window))
  (in-main-thread ()
    (#/orderOut: (native-window Self) nil)))


(defmethod SCREEN-WIDTH ((Self window))
  (truncate (pref (#/frame (or (#/screen (native-window Self))
                               (#/mainScreen ns:ns-screen))) 
                  <NSR>ect.size.width)))


(defmethod SCREEN-HEIGHT ((Self window))
  (truncate (pref (#/frame (or (#/screen (native-window Self))
                               (#/mainScreen ns:ns-screen))) 
                  <NSR>ect.size.height)))


(defmethod SCREEN-HEIGHT ((Self null))
  (truncate (pref (#/frame (#/mainScreen ns:ns-screen))
                  <NSR>ect.size.height)))


(defmethod (setf TITLE) :after (Title (self window))
  (#/setTitle: (native-window Self) (native-string Title)))


(defvar *Run-Modal-Return-Value* nil "shared valued used to return the run modal values")

;; Modal windows

(defmethod SHOW-AND-RUN-MODAL ((Self window))
  (declare (special *Run-Modal-Return-Value*))
  (setq *Run-Modal-Return-Value* nil)
  (when (#/isVisible (native-window Self))
    (error "cannot run modal a window that is already visible"))
  (in-main-thread () (#/makeKeyAndOrderFront: (native-window self) (native-window self)))
  (let ((Code (in-main-thread () 
                              (#/runModalForWindow: (#/sharedApplication ns:ns-application)
                                      (native-window Self)))))
    (declare (ignore Code))
    ;; ignore Code for now
    (in-main-thread () (#/close (native-window Self)))
    (case *Run-Modal-Return-Value*
      (:cancel  (throw :cancel nil))
      (t *Run-Modal-Return-Value*))))


(defmethod STOP-MODAL ((Self window) Return-Value)
  (setq *Run-Modal-Return-Value* Return-Value)
  (#/stopModal (#/sharedApplication ns:ns-application)))


(defmethod CANCEL-MODAL ((Self window))
  (setq *Run-Modal-Return-Value* :cancel)
  (#/stopModal (#/sharedApplication ns:ns-application)))


;; screen mode

(defvar *Window-Full-Screen-Restore-Sizes* (make-hash-table))


(defmethod SWITCH-TO-FULL-SCREEN-MODE ((Self window))
  (setf (gethash Self *Window-Full-Screen-Restore-Sizes*) (#/frame (native-window Self)))
  #-cocotron (#_SetSystemUIMode #$kUIModeAllSuppressed #$kUIOptionAutoShowMenuBar)
  (setf (full-screen Self) t)
  ;;; random sizing to trigger #/constrainFrameRect:toScreen
  ;;; (set-size Self 100 100)
  (#/orderFront: (native-window Self) (native-window Self))
  (#/makeKeyWindow (native-window Self)))


(defmethod SWITCH-TO-WINDOW-MODE ((Self window))
  #-cocotron (#_SetSystemUIMode #$kUIModeNormal 0)
  (setf (full-screen Self) nil)
  (let ((Frame (gethash Self *Window-Full-Screen-Restore-Sizes*)))
    (when Frame
      (#/setFrame:display:animate: (native-window Self) Frame #$YES #$NO))))


(defmethod MAKE-KEY-WINDOW ((Self window))
  (#/makeKeyWindow (native-window self)))

(defmethod BRING-TO-FRONT ((Self Window))
  (#/makeKeyWindow (native-window self))
  (#/orderFront: (native-window self) nil))

(defmethod START-ACCEPTING-MOUSE-MOUVED-EVENTS ((Self Window))
  (#/setAcceptsMouseMovedEvents: (native-window Self) #$YES))
  
;__________________________________
; Window query functions            |
;__________________________________/

;;This method still has lots of issues:
;;First, I have to add one to i.  This seems to cause the return value to to match up with orderedIndex but also seems very dangerous, and unlikely
;;to be a universal solution.  This was tested by making four different application windows and commenting the first three lines of this method so 
;;that it always returned the cocotron value.  I tried arranging the windows in many different ways and comparing the return value of this method 
;;to the value return by (#/orderedIndex Window), and it was always the same.  Another issue is that it seems that the method 
;;(#/sharedApplication ns::ns-application) works differently in cocotron.  Used the method ordered-test I determined that (#/sharedApplication ns::ns-application)
;;returns the order in which the windows are stacked on the mac version but in cocotron it return the order in which they were created.  It seems that this may not
;;be a good solution after all.  
(defun ORDERED-WINDOW-INDEX (Window)
  #-:cocotron 
  (#/orderedIndex Window)
  #+:cocotron
   (let ((window-array  (#/orderedWindows (#/sharedApplication ns::ns-application)))) 
     (dotimes (i (#/count window-array))
       (let ((array-window (#/objectAtIndex: window-array i)))         
         (if (equal window array-window)
           (progn            
             (return-from ordered-window-index (+ 1 i))))))
     (return-from ordered-window-index nil)))


(defun ORDERED-TEST ()
  (let ((window-array  (#/orderedWindows (#/sharedApplication ns::ns-application)))) 
    (dotimes (i (#/count window-array))
      (let ((array-window (#/objectAtIndex: window-array i)))    
        (print (#/title array-window))))))


(defun FIND-WINDOW-AT-SCREEN-POSITION (screen-x screen-y &key Type) "
  Return a LUI window at screen position x, y.
  If there is no window return nil
  If there are multiple windows return the topmost one"
  (multiple-value-bind (x y) (lui-screen-coordinate screen-x screen-y)
    (let ((Lui-Windows nil)
          (All-Windows (#/windows (#/sharedApplication ns::ns-application))))
      (dotimes (i (#/count All-Windows) (first (sort Lui-Windows #'< :key #'(lambda (w) (ordered-window-index (native-window w))))))
        (let ((Window (#/objectAtIndex: All-Windows i)))
          (when (and 
                 (#/isVisible Window)
                 (slot-exists-p Window 'lui-window)
                 (if Type 
                   (subtypep (type-of (lui-window Window)) (find-class Type))
                   t))
            (let ((Frame (#/frame Window)))
              (when (and (<= (pref Frame <NSR>ect.origin.x) x (+ (pref Frame <NSR>ect.origin.x) (pref Frame <NSR>ect.size.width)))
                         (<= (pref Frame <NSR>ect.origin.y) y (+ (pref Frame <NSR>ect.origin.y) (pref Frame <NSR>ect.size.height))))
                (push (lui-window Window) Lui-Windows)))))))))

;; (find-window-at-screen-position 10 100)

;__________________________________
; NATIVE-WINDOW-VIEW                |
;__________________________________/

(defclass native-window-view (ns:ns-view)
  ((lui-window :accessor lui-window :initarg :lui-window))
  (:metaclass ns:+ns-object
	      :documentation "dispatch NS events to LUI events. A LUI window needs to contain on dispatch view"))


(objc:defmethod (#/mouseDown: :void) ((self native-window-view) event)
  (let ((mouse-loc (#/locationInWindow event)))
    (view-event-handler (lui-window Self) 
                        (make-instance 'mouse-event
                          :x (truncate (pref mouse-loc :<NSP>oint.x))
                          :y (truncate (- (height (lui-window Self)) (pref mouse-loc :<NSP>oint.y)))
                          :event-type (native-to-lui-event-type (#/type event))
                          :native-event Event))))

(objc:defmethod (#/rightMouseDown: :void) ((self native-window-view) event)
  (declare (ignore event))
  (print "++RIGHT MOUSE DOWN"))

#|
  (let ((mouse-loc (#/locationInWindow event)))
    (view-event-handler (lui-window Self) 
                        (make-instance 'mouse-event
                          :x (truncate (pref mouse-loc :<NSP>oint.x))
                          :y (truncate (- (height (lui-window Self)) (pref mouse-loc :<NSP>oint.y)))
                          :event-type (native-to-lui-event-type (#/type event))
                          :native-event Event))))
|#

(objc:defmethod (#/mouseUp: :void) ((self native-window-view) event)
  (let ((mouse-loc (#/locationInWindow event)))
    (view-event-handler (lui-window Self) 
                        (make-instance 'mouse-event
                          :x (truncate (pref mouse-loc :<NSP>oint.x))
                          :y (truncate (- (height (lui-window Self)) (pref mouse-loc :<NSP>oint.y)))
                          :event-type (native-to-lui-event-type (#/type event))
                          :native-event Event))))


(objc:defmethod (#/mouseDragged: :void) ((self native-window-view) event)
  (let ((mouse-loc (#/locationInWindow event)))
    ;;(format t "~%dragged to ~A, ~A," (pref mouse-loc :<NSP>oint.x) (- (height (lui-window Self)) (pref mouse-loc :<NSP>oint.y)))
    (view-event-handler (lui-window Self) 
                        (make-instance 'mouse-event
                          :x (truncate (pref mouse-loc :<NSP>oint.x))
                          :y (truncate (- (height (lui-window Self)) (pref mouse-loc :<NSP>oint.y)))
                          :dx (truncate (#/deltaX Event))
                          :dy (truncate (#/deltaY Event))
                          :event-type (native-to-lui-event-type (#/type event))
                          :native-event Event))))


(objc:defmethod (#/isFlipped :<BOOL>) ((self native-window-view))
  ;; Flip to coordinate system to 0, 0 = upper left corner
  #$YES)

;****************************************************
; CONTROLs                                          *
;****************************************************

(defclass native-target (ns:ns-object)
  ((native-control :accessor native-control :initarg :native-control)
   (lui-control :accessor lui-control :initarg :lui-control))
  (:metaclass ns:+ns-object)
  (:documentation "receives action events and forwards them to lui control"))


(defun PRINT-CONDITION-UNDERSTANDABLY (Condition &optional (Message "") (Stream t))
  (format Stream "~%~A~A: " Message (type-of Condition))
  (ccl::report-condition Condition Stream))


(objc:defmethod (#/activateAction :void) ((self native-target))
  ;; dispatch action to window + target
  ;; catch errors to avoid total crash of CCL
  (catch :activate-action-error
    (handler-bind
        ((warning #'(lambda (Condition) 
                      (print-condition-understandably Condition "activate action warning, ")
                      (muffle-warning)))
         (condition #'(lambda (Condition)
                        ;; no way to continue
                        (print-condition-understandably Condition "activate action error, ")
                        ;; produce a basic stack trace
                        (format t "~% ______________Exception in thread \"~A\"___(backtrace)___" (slot-value *Current-Process* 'ccl::name))
                        (ccl:print-call-history :start-frame-number 1 :detailed-p nil)
                        (throw :activate-action-error Condition))))
      (invoke-action (lui-control Self)))))


(defmethod INITIALIZE-EVENT-HANDLING ((Self control))
  (#/setTarget: (native-view Self) 
                (make-instance 'native-target 
                  :native-control (native-view Self)
                  :lui-control Self))
  (#/setAction: (native-view Self) (objc::@selector #/activateAction)))


(objc:defmethod (#/isFlipped :<BOOL>) ((self ns:ns-control))
  ;; ALL controls: Flip to coordinate system to 0, 0 = upper left corner
  #$YES)


;__________________________________
; BUTTON                           |
;__________________________________/

(defclass native-button (ns:ns-button)
  ((lui-view :accessor lui-view :initarg :lui-view))
  (:metaclass ns:+ns-object))


(defmethod make-native-object ((Self button-control))
  (let ((Native-Control (make-instance 'native-button :lui-view Self)))
    (ns:with-ns-rect (Frame (x self) (y Self) (width Self) (height Self))
      (#/initWithFrame: Native-Control Frame)

      (#/setButtonType: Native-Control #$NSMomentaryPushInButton)
      (when (default-button Self)
        (#/setKeyEquivalent: Native-Control  #@#.(string #\return)))
      (#/setImagePosition: Native-Control #$NSNoImage)
      ;; Until Cocotron issue 366 is fixed, don't set the bezel style
      ;; as it causes the button to be invisible
      #-cocotron (#/setBezelStyle: Native-Control #$NSRoundedBezelStyle)
      (#/setTitle: Native-Control (native-string (text Self))))
    Native-Control))


(defmethod (setf text) :after (Text (Self button-control))
  (#/setTitle: (native-view Self) (native-string Text)))



;__________________________________
; BEVEL BUTTON                      |
;__________________________________/

(defclass native-bevel-button (ns:ns-button)
  ((lui-view :accessor lui-view :initarg :lui-view))
  (:metaclass ns:+ns-object))


(defmethod make-native-object ((Self bevel-button-control))
  (let ((Native-Control (make-instance 'native-bevel-button :lui-view Self)))
    (ns:with-ns-rect (Frame (x self) (y Self) (width Self) (height Self))
      (#/initWithFrame: Native-Control Frame)
      (#/setButtonType: Native-Control #$NSMomentaryPushInButton)
      (#/setImagePosition: Native-Control #$NSNoImage)
      (#/setBezelStyle: Native-Control #$NSThickerSquareBezelStyle)
      (#/setTitle: Native-Control (native-string (text Self))))
    Native-Control))


(defmethod (setf text) :after (Text (Self bevel-button-control))
  (#/setTitle: (native-view Self) (native-string Text)))

#|

;__________________________________
; Tab-View                         |
;__________________________________/



(defclass native-tab-view (ns:ns-tab-view)
  ((lui-view :accessor lui-view :initarg :lui-view))
  (:metaclass ns:+ns-object))

(defmethod make-native-object ((Self tab-view-control))
  (let ((Native-Control (make-instance 'native-tab-view :lui-view Self)))
    (ns:with-ns-rect (Frame (x self) (y Self) (width Self) (height Self))
      (#/initWithFrame: Native-Control Frame)

  
      )
    Native-Control))


(defmethod ADD-TAB-VIEW-ITEM ((Self tab-view-control) text)
  (let ((tabViewItem (make-instance 'ns:ns-tab-view-item
                       :with-identifier (native-string text))))
    (#/setLabel: tabViewItem (Native-String text))
    (#/addTabViewItem: (native-view self) tabViewItem)))

(defmethod initialize-event-handling ((Self tab-view-control))
  (declare (ignore self)))

(defmethod MAP-SUBVIEWS ((Self tab-view-control) Function &rest Args)
  (declare (ignore Function Args))
  ;; no Cocoa digging
  )

;__________________________________
; Tab-View-Item                    |
;__________________________________/

(defclass native-tab-view (ns:ns-tab-view-item)
  ((lui-view :accessor lui-view :initarg :lui-view))
  (:metaclass ns:+ns-object))

(defmethod make-native-object ((Self tab-view-item-control))
  (let ((Native-Control (make-instance 'ns:ns-tab-view-item
                       :with-identifier (native-string (text self)))))
    (ns:with-ns-rect (Frame (x self) (y Self) (width Self) (height Self))
     ; (#/initWithFrame: Native-Control Frame)
#|      
(let ((tab-view (make-instance 'ns:ns-view)))
        (#/initWithFrame: tab-view Frame)
        (#/setView: Native-Control tab-view)
      )
|#
    Native-Control)))

(defmethod initialize-event-handling ((Self tab-view-item-control))
  (declare (ignore self)))

(defmethod ADD-TAB-VIEW-ITEM-VIEW ((Self tab-view-item-control) view)
  (#/setView: (Native-View self) (native-view view)))

|#

;__________________________________
; CHECKBOX BUTTON                 |
;__________________________________/


(defclass native-checkbox (ns:ns-button)
  ((lui-view :accessor lui-view :initarg :lui-view))
  (:metaclass ns:+ns-object))


(defmethod make-native-object ((Self checkbox-control))
  (let ((Native-Control (make-instance 'native-checkbox :lui-view Self)))
    (ns:with-ns-rect (Frame (x self) (y Self) (width Self) (height Self))
      (#/initWithFrame: Native-Control Frame)
      (#/setButtonType: Native-Control #$NSSwitchButton)
      (#/setImagePosition: Native-Control #$NSImageLeft)
      (if (start-checked self)
        (#/setState: Native-Control #$NSOnState))
      (if (image-on-right self)
        (#/setImagePosition: Native-Control #$NSImageRight)
        (#/setImagePosition: Native-Control #$NSImageLeft))
      ;(#/setBezelStyle: Native-Control #$NSRoundedBezelStyle)
      (#/setTitle: Native-Control (native-string (text Self))))
    Native-Control))


(defmethod VALUE ((self checkbox-control))
  (if (eql (#/state (Native-View self)) #$NSOnState)
    't
    nil))

(defmethod (setf text) :after (Text (Self checkbox-control))
  (#/setTitle: (native-view Self) (native-string Text)))


(defmethod ENABLE ((self checkbox-control))
  (#/setState: (Native-View self) #$NSOnState))

;__________________________________
; STRING-LIST-TEXT-VIEW            |
;__________________________________/

(defclass NATIVE-STRING-LIST-TEXT-VIEW (ns:ns-text-view)
  ((lui-view :accessor lui-view :initarg :lui-view))
  (:metaclass ns:+ns-object))


(defclass STRING-LIST-TEXT-VIEW (control)
  ((is-selected :accessor is-selected :initform nil)
   (container :accessor container :initform nil)
   ;(lui-view :accessor lui-view :initform nil)
   ;(text :accessor text :initform nil)
   )
  (:documentation "A text field that detects mouse events.  "))

(defmethod MAKE-NATIVE-OBJECT ((Self string-list-text-view))
  (let ((Native-Control (make-instance 'native-string-list-text-view :lui-view Self)))
    (ns:with-ns-rect (Frame (x self) (y Self) (width Self) (height Self))
     
      (#/initWithFrame: Native-Control Frame)
      ;(#/setBackgroundColor: self (#/whiteColor ns:ns-color))
      Native-Control)))

(objc:defmethod (#/drawRect: :void) ((self native-string-list-text-view) (rect :<NSR>ect))
  (ns:with-ns-rect (Frame (NS:NS-RECT-X rect) (NS:NS-RECT-Y rect) (- (NS:NS-RECT-WIDTH rect) 1)(NS:NS-RECT-HEIGHT rect))
  (call-next-method Frame) 
  (if (is-selected (lui-view self))
    (progn
      ;; Draw the selected item with a blue selection background.  
      (#/set (#/colorWithDeviceRed:green:blue:alpha: ns:ns-color 0.0 0.2 1.0 .6))
      
        (#/fillRect: ns:ns-bezier-path Frame)))))

(defmethod MAP-SUBVIEWS ((Self string-list-text-view) Function &rest Args)
  (declare (ignore Function Args))
  ;; no Cocoa digging
  )

(defmethod initialize-event-handling ((Self string-list-text-view))
  ;; no event handling for rows
  )

(objc:defmethod (#/mouseDown: :void) ((self native-string-list-text-view) Event)
  (declare (ignore Event))
  (if (list-items (container (lui-view self)))
    (dolist (item (list-items (container (lui-view self))))
      (setf (is-selected item) nil)
      (#/setNeedsDisplay: (native-view item) #$YES)))
  (setf (is-selected (lui-view self)) t)
  (setf (selected-string (container (lui-view self))) (text (lui-view self)))
  (#/setNeedsDisplay: self #$YES)
  (funcall (action (container (lui-view Self))) (window (container (lui-view Self))) (target (container (lui-view Self)))))


;__________________________________
; STRING-LIST-VIEW-CONTROL         |
;__________________________________/

(defclass NATIVE-STRING-LIST-VIEW (ns:ns-view)
  ((lui-view :accessor lui-view :initarg :lui-view))
  (:metaclass ns:+ns-object))


(objc:defmethod (#/drawRect: :void) ((self native-string-list-view) (rect :<NSR>ect))
  (call-next-method rect)
  (layout (lui-view self))
  (set-size (lui-view self) (NS:NS-RECT-WIDTH rect) (NS:NS-RECT-HEIGHT rect))
  (#/set (#/colorWithDeviceRed:green:blue:alpha: ns:ns-color 1.0 1.0 1.0 1.0))
  (#/fillRect: ns:ns-bezier-path rect)
  (#/set (#/colorWithDeviceRed:green:blue:alpha: ns:ns-color .5 .5 .5 1.0))
  (#/strokeRect: ns:ns-bezier-path rect))


(objc:defmethod (#/isFlipped :<BOOL>) ((self native-string-list-view))
  ;; Flip to coordinate system to 0, 0 = upper left corner
  #$YES)


(defmethod MAP-SUBVIEWS ((Self string-list-view-control) Function &rest Args)
  (declare (ignore Function Args))
  ;; no Cocoa digging
  )


(defmethod MAKE-NATIVE-OBJECT ((Self string-list-view-control))
  (let ((Native-Control (make-instance 'native-string-list-view :lui-view Self)))
    (ns:with-ns-rect (Frame (x self) (y Self) (width Self) (height Self))
      (#/initWithFrame: Native-Control Frame)
      ;(#/setBackgroundColor: self (#/whiteColor ns:ns-color))
      Native-Control)))


(defmethod ADD-STRING-LIST-ITEM ((Self string-list-view-control) string)
  "Adds an item to the string-list that will display the text contained in the variable string"
  
    (let ((text (make-instance 'string-list-text-view))) 
      
      
    (ns:with-ns-rect (Frame2 1 (+ 1 (* (item-height self) (length (list-items self)))) (width self)  20 )
      (setf (container text) self)
      (setf (text text) string)
      (#/initWithFrame: (native-view text) Frame2)
      (#/insertText: (native-view text) (native-string string))
      (#/setBackgroundColor: (native-view text) (#/whiteColor ns:ns-color))
      (#/setDrawsBackground:  (native-view text) #$YES)
      (#/setEditable: (native-view text) #$NO)
      (#/setSelectable: (native-view text) #$NO)
      (#/addSubview:  (Native-view self) (native-view text)))
      (case (list-items self)
      (nil 
       (setf (list-items self) (list text))
       (setf (is-selected (first (list-items self))) t)
       (display self))
      (t (setf (list-items self) (append (list-items self) (list text)))))))


(defmethod SET-LIST ((Self string-list-view-control) list) 
  "Used to set the string-list to a given list instead setting the list string by string.  Also will select the first item in the list.  "

  (dolist (subview (gui::list-from-ns-array (#/subviews (native-view self))))
    (#/removeFromSuperview subview))
  (setf (list-items self) nil)
  (dolist (item list)
    (add-string-list-item self item))
  (setf (is-selected (first (list-items self))) t)
  (setf (selected-string self) (text (first (list-items self))))
  ;(#/setNeedsDisplay: (native-view self) #$YES)
  (display self))


(defmethod SELECT-ITEM ((Self string-list-view-control) item-name) 
  (dolist (item (list-items self))
    (if (equal (string-capitalize (text item)) (string-capitalize item-name))
      (progn
        (setf (is-selected item) t)
        (setf (selected-string self) (text item))
        (return-from select-item t))
      (setf (is-selected item) nil)))
  nil)


(defmethod initialize-event-handling ((Self string-list-view-control))
  ;; no event handling for rows
  )

(defclass ATTRIBUTE-TEXT-VIEW-DELEGATE (ns:ns-object)
  ((lui-view :accessor lui-view :initform nil :initarg :lui-view))
  (:metaclass ns:+ns-object
	      :documentation " delegate"))


(defclass NATIVE-attribute-editor-view (ns:ns-text-field)
  ((lui-view :accessor lui-view :initarg :lui-view))
  (:metaclass ns:+ns-object))


(defmethod MAKE-NATIVE-OBJECT ((self attribute-editor-view))
  (let ((Native-Control (make-instance 'native-attribute-editor-view :lui-view Self)))
    (ns:with-ns-rect (Frame (x self) (y Self) (width Self) (height Self))
      (#/initWithFrame: Native-Control Frame)
      (#/setStringValue: Native-Control (native-string (Text self)))
      ;(#/setBackgroundColor: self (#/whiteColor ns:ns-color))
      Native-Control)))

(defmethod (setf text) :after (Text (self attribute-editor-view))
  (#/setStringValue: (native-view Self) (native-string Text)))

(defmethod VALUE ((self attribute-editor-view))
  (ccl::lisp-string-from-nsstring 
   (#/stringValue (native-view Self))))

(defmethod (setf VALUE)  (Text (self attribute-editor-view))
  (#/setStringValue: (native-view Self) (native-string Text)))

(objc:defmethod (#/textDidChange: :void) ((self native-attribute-editor-view) Notification)
  (call-next-method Notification)
  )


(objc:defmethod (#/textDidBeginEditing: :void) ((self native-attribute-editor-view) Notification)
  (setf (value-save (lui-view self)) (#/stringValue self))
  (call-next-method Notification))


(objc:defmethod (#/textDidEndEditing: :void) ((self native-attribute-editor-view) Notification)
  (call-next-method Notification)
  (text-did-end-editing (lui-view self)))

#|
(objc:defmethod (#/textDidEndEditing: :void) ((self native-attribute-value-list-text-view) Notification)
  (when (read-from-string (ccl::lisp-string-from-nsstring (#/stringValue self)) nil nil)
    (unless (numberp  (read-from-string (ccl::lisp-string-from-nsstring (#/stringValue self)) nil nil))
      (if (value-save (lui-view self))
        (#/setStringValue: self (value-save (lui-view self)))))
    (call-next-method Notification)
    (unless (attribute-owner (lui-view  self))
      (setf (attribute-owner (lui-view  self)) (part-of  (lui-view  self))))
    (if (attribute-owner (lui-view  self))
      (funcall (attribute-changed-action (lui-view self)) (attribute-owner (lui-view self))  (window (lui-view self))  (attribute-symbol (container (lui-view self))) (read-from-string (ccl::lisp-string-from-nsstring (#/stringValue self)) nil nil)) 
      (print "NOT__"))))
|#

(defmethod TEXT-DID-END-EDITING ((Self attribute-value-list-text-view))
  (when (read-from-string (ccl::lisp-string-from-nsstring (#/stringValue (native-view self))) nil nil)
    (unless (numberp  (read-from-string (ccl::lisp-string-from-nsstring (#/stringValue (native-view self))) nil nil))
      (if (value-save self)
        (#/setStringValue: (native-view self) (value-save self))))
    (unless (attribute-owner self)
      (setf (attribute-owner self) (part-of  self)))
    (if (attribute-owner self)
      (funcall (attribute-changed-action self) (attribute-owner self)  (window self)  (attribute-symbol (container self)) (read-from-string (ccl::lisp-string-from-nsstring (#/stringValue (native-view self))) nil nil)) 
      )))

;__________________________________
; ATTRIBUTE-VALUE-LIST-ITEM-VIEW   |
;__________________________________/


(defclass ATTRIBUTE-VALUE-LIST-ITEM-VIEW (ns:ns-view)
  ((is-selected :accessor is-selected :initform nil)
   (container :accessor container :initform nil :initarg :container)
   (lui-view :accessor lui-view :initform nil)
   (text :accessor text :initform nil :initarg :text )
   (height :accessor height :initform nil :initarg :height )
   (width :accessor width :initform nil :initarg :width )
   (attribute-symbol :accessor attribute-symbol :initarg :attribute-symbol :initform nil :documentation "The text field will store the name of attribute as a native-string so for conveniance we store the attribute as a symbol here")
   (attribute-value :accessor attribute-value :initform 0 :initarg :attribute-value)
   (value-text-field :accessor value-text-field :initform nil :documentation "Editable NSTextField containg the value of the attribute")
   (name-text-field :accessor name-text-field :initform nil :documentation "NSTextView containg the name of the attribute" )
   (attribute-owner :accessor attribute-owner :initform nil :initarg :attribute-owner :documentation "An owner can be associated with this object and if so, it will be notifed when this objects value-text-field is editted.  In order for this to work, you will need to an attribute-changed-action.")
   (attribute-changed-action :accessor attribute-changed-action :initform nil :initarg :attribute-changed-action :documentation "The action that should be called when the attribute's value has been changed" )
   (timer-triggers :accessor timer-triggers :initform nil :documentation "when to start TIME triggers")
   )
  (:metaclass ns:+ns-object
              :documentation "An item of an attribute-value-list-view-control, this item is made up of a text view displaying the name of the attribute, and an editable field displaying the value.  "))


(defmethod INITIALIZE-INSTANCE :after ((Self attribute-value-list-item-view) &rest Args)
  (declare (ignore Args))
  (let ((text (#/alloc ns:ns-text-view))) 
    (ns:with-ns-rect (Frame2 1 (+ 1 0) (* .5 (width self))  20 )
      (#/initWithFrame: text Frame2)
      (#/insertText: text (native-string (text self)))
      (#/setBackgroundColor: text (#/whiteColor ns:ns-color))
      (#/setDrawsBackground:  text #$YES)
      (#/setEditable: text #$NO)
      (#/setSelectable: text #$NO)
      (setf (name-text-field self) text)
      (#/addSubview:  self text))
    (let ((value-text (make-instance 'attribute-value-list-text-view :container self :attribute-owner (attribute-owner self) :attribute-changed-action (attribute-changed-action self)))) 
      (ns:with-ns-rect (Frame2 (* .5 (width self)) 1 (* .5 (width self))  20 )
        (#/initWithFrame: (native-view value-text) Frame2)
        (#/setStringValue:  (native-view value-text) (native-string (write-to-string (attribute-value self))))
        (#/setBackgroundColor: (native-view value-text) (#/whiteColor ns:ns-color))
        (#/setDrawsBackground:  (native-view value-text) #$YES)
        (#/setSelectable: (native-view value-text) #$YES)
        (#/setEditable: (native-view value-text) #$YES)
        (setf (value-text-field self) (native-view value-text))
        (#/addSubview:  self (native-view value-text))))))


(defmethod TIMER-DUE-P ((Self attribute-value-list-item-view) Ticks) 
  (let ((Time (getf (timer-triggers Self) Ticks 0))
        (Now (get-internal-real-time)))
    (when (or (>= Now Time)                          ;; it's time
              (> Time (+ Now Ticks Ticks)))    ;; timer is out of synch WAY ahead
      (setf (getf (timer-triggers Self) Ticks) (+ Now Ticks))
      t)))


(objc:defmethod (#/drawRect: :void) ((Self attribute-value-list-item-view) (rect :<NSR>ect))
  (call-next-method rect)
  (when (timer-due-p self (truncate (* 1.0 internal-time-units-per-second)))
    (#/setTextColor: (value-text-field self) (#/blackColor ns:ns-color))))

;___________________________________
; ATTRIBUTE VALUE LIST VIEW CONTROL |
;__________________________________/

(defclass NATIVE-ATTRIBUTE-VALUE-LIST-VIEW-CONTROL (ns:ns-view)
  ((lui-view :accessor lui-view :initarg :lui-view))
  (:metaclass ns:+ns-object))


(objc:defmethod (#/isFlipped :<BOOL>) ((self native-attribute-value-list-view-control))
  ;; Flip to coordinate system to 0, 0 = upper left corner
  #$YES)


(defmethod MAP-SUBVIEWS ((Self attribute-value-list-view-control) Function &rest Args)
  (declare (ignore Function Args))
  ;; no Cocoa digging
  )

(defmethod MAKE-NATIVE-OBJECT ((Self attribute-value-list-view-control))
  (let ((Native-Control (make-instance 'native-attribute-value-list-view-control :lui-view Self)))
    (ns:with-ns-rect (Frame (x self) (y Self) (width Self) (height Self))
      (#/initWithFrame: Native-Control Frame)
      Native-Control)))


(defmethod INITIALIZE-INSTANCE :after ((Self attribute-value-list-view-control) &rest Args)
  "We need to create a new thread that will set the color of attribute values back to black"
  (declare (ignore args))
  ;(call-next-method)
  (setf (color-update-process self)
    (process-run-function
     '(:name "Attribute Window Thread" :priority 1)
     #'(lambda ()
         (loop
           (catch-errors-nicely 
            "OpenGL Animation"
            (reset-color-of-items self)
            (sleep .01)))))))


(defmethod RESET-COLOR-OF-ITEMS ((Self attribute-value-list-view-control))
  (dolist (item (list-items self))
    (when (timer-due-p item (truncate (* 1.0 internal-time-units-per-second)))
      (#/setTextColor: (value-text-field item) (#/blackColor ns:ns-color)))))


(defmethod ADD-ATTRIBUTE-LIST-ITEM ((Self attribute-value-list-view-control) string value &key (action nil) (owner nil))
  "Adds an item to the attribute-list that will display the text contained in the variable string"
  (if (attribute-owner self)
    (setf owner (attribute-owner self)))
  (if (attribute-changed-action self)
    (setf action (attribute-changed-action self)))
  (let ((item (make-instance 'attribute-value-list-item-view :attribute-symbol string :container self :width (width self) :height (item-height self) :attribute-value value :text string :attribute-changed-action action :attribute-owner owner) ))
    (ns:with-ns-rect (Frame2 1 (+ 1 (* (item-height self) (length (list-items self)))) (Width self)  20 )
      (#/initWithFrame: item Frame2))
    (#/addSubview:  (Native-view self) item)
    (case (list-items self)
      (nil 
       (setf (list-items self) (list item))
       (setf (is-selected (first (list-items self))) t)
       (display self))
      (t (setf (list-items self) (append (list-items self) (list item)))))))


(defmethod SET-LIST ((Self attribute-value-list-view-control) list) 
  "Used to set the string-list to a given list instead setting the list string by string.  Also will select the first item in the list.  "
  (dolist (subview (gui::list-from-ns-array (#/subviews (native-view self))))
    (#/removeFromSuperview subview))
  (setf (list-items self) nil)
  (dolist (item list)
    (add-attribute-list-item self (first item) (second item) :action (attribute-changed-action self) :owner (attribute-owner self)))
  (display self))


(defmethod SET-VALUE-OF-ITEM-WITH-NAME ((Self attribute-value-list-view-control) name value)
  (dolist (item (list-items self))
    (when (equal (text item) name)
      (unless (equal (write-to-string value) (ccl::lisp-string-from-nsstring (#/stringValue (value-text-field item))))
        (setf (attribute-value item) value)
        (#/setStringValue: (value-text-field item) (native-string (write-to-string Value)))
        (#/setTextColor: (value-text-field item) (#/redColor ns:ns-color)))
      (return-from set-value-of-item-with-name t)))
  (add-attribute-list-item self name value)
  (layout self)
  (display self))


(defmethod SELECT-ITEM ((Self attribute-value-list-view-control) item-name) 
  (dolist (item (list-items self))
    (if (equal (string-capitalize (text item)) (string-capitalize item-name))
      (progn
        (setf (is-selected item) t)
        (setf (selected-string self) (text item))
        (return-from select-item t))
      (setf (is-selected item) nil)))
  nil)


(defmethod initialize-event-handling ((Self attribute-value-list-view-control))
  ;; no event handling for rows
  )

;(truncate (* Time internal-time-units-per-second))
;__________________________________
; SCROLLER-CONTROL                 |
;__________________________________/

(defclass NATIVE-SCROLLER (ns:ns-scroller)
  ((lui-view :accessor lui-view :initarg :lui-view))
  (:metaclass ns:+ns-object))


(defmethod MAKE-NATIVE-OBJECT ((Self scroller-control))
  (let ((Native-Control (make-instance 'native-scroller :lui-view Self)))
    (ns:with-ns-rect (Frame (x self) (y Self) (width Self) (height Self))
      #-cocotron 
      ;;cocotron does not support the NSSmallControlSize
      (when (small-scroller-size self)
          (setf (width self) (- (width self) 4))
          (#/setControlSize: Native-Control #$NSSmallControlSize))
      (#/sizeToFit Native-Control)
      (#/initWithFrame: Native-Control Frame)
      (#/setFloatValue:knobProportion: Native-Control 0.0 (knob-proportion self))
      (#/setArrowsPosition: Native-Control #$NSScrollerArrowsMinEnd ) 
      (#/setEnabled: Native-Control #$YES)
      Native-Control)))


(defmethod SET-SCROLLER-POSITION ((Self scroller-control) float)
  (#/setFloatValue:knobProportion: (native-view self) float .2))


(defmethod VALUE ((Self scroller-control))
  (#/floatValue (native-view self)))


;__________________________________
;  Image Button                    |
;__________________________________/

(defclass native-button-image (ns:ns-button)
  ((lui-view :accessor lui-view :initarg :lui-view))
  (:metaclass ns:+ns-object))


(defmethod make-native-object ((Self image-button-control))
  (let ((Native-Control (make-instance 'native-button-image :lui-view Self)))
    (let ((NS-Image (#/alloc ns:ns-image)))
      (ns:with-ns-rect (Frame (x self) (y Self) (width Self) (height Self))
        (let ((Path (native-path "lui:resources;buttons;" (image Self))))
          (unless (probe-file Path) (error "no such image file for button ~A" (image Self)))
          (#/initWithContentsOfFile: NS-Image  (native-string (native-path "lui:resources;buttons;" (image Self))))
          (#/initWithFrame: Native-Control Frame)
          (#/setButtonType: Native-Control #$NSOnOffButton)   ;;;NSMomentaryPushInButton)
          (#/setImagePosition: Native-Control #$NSImageOnly)
          (#/setImage: Native-Control NS-Image)
          (#/setBezelStyle: Native-Control #$NSShadowlessSquareBezelStyle)
          (#/setTitle: Native-Control (native-string (text Self)))))
      Native-Control)))


(objc:defmethod (#/drawRect: :void) ((self native-button-image) (rect :<NSR>ect))
  (call-next-method rect)
  #+cocotron
  (if (selected-in-cluster (lui-view self))
    (progn
      (#/set (#/colorWithDeviceRed:green:blue:alpha: ns:ns-color .2 .2 .2 .62))
      (#/fillRect: ns:ns-bezier-path rect))))

(defmethod (setf text) :after (Text (Self image-button-control))
  (#/setTitle: (native-view Self) (native-string Text)))


(defmethod SET-BUTTON-OFF ((Self image-button-control))
  (#/setState: (native-view self) #$NSOffState))


(defmethod SET-BUTTON-ON ((Self image-button-control))
  (#/setState: (native-view self) #$NSOnState))

;__________________________________
; RADIO BUTTON                     |
;__________________________________/

(defclass native-radio-button (ns:ns-matrix)
  ((lui-view :accessor lui-view :initarg :lui-view))
  (:metaclass ns:+ns-object))


(defmethod make-native-object ((Self radio-button-control))
  (let ((Native-Control (make-instance 'native-radio-button :lui-view Self))
        (prototype (#/init (#/alloc ns:ns-button-cell))))
    (unless (elements self)
      (setf (elements self) (#/init (#/alloc ns:ns-mutable-array))))
    (ns:with-ns-rect (Frame (x self) (y Self) (width Self) (height Self))
      (#/setTitle: prototype (native-string "Option"))
      (#/setButtonType: prototype #$NSRadioButton)
      (#/initWithFrame:mode:prototype:numberOfRows:numberOfColumns: Native-Control Frame #$NSRadioModeMatrix prototype 3 1)
      (let ((cells (#/cells Native-Control))
            (cell (#/init (#/alloc ns:ns-button-cell))))
        (#/setTitle: cell (native-string "options3"))
        (#/setButtonType: cell #$NSRadioButton)       
        (#/setTitle: (#/objectAtIndex: cells '0) #@"Option1")
        (#/putCell:atRow:column: Native-Control cell '1 '0)))
    Native-Control))


(defmethod (setf text) :after (Text (Self radio-button-control))
  (#/setTitle: (native-view Self) (native-string Text)))


(defmethod GET-SELECTED-ACTION ((Self radio-button-control))
  (elt (actions self)  (#/indexOfObject: (elements Self) (#/selectedCell (native-view self)))))


(defmethod RADIO-ACTION ((window window) (self Radio-Button-Control))
  (let ((action (get-selected-action self)))
    (funcall action Window Self)))


(defmethod FINALIZE-CLUSTER ((Self radio-button-control))
  (ns:with-ns-rect (Frame (x self) (y Self) (width Self) (height Self))
    (let ((prototype (#/init (#/alloc ns:ns-button-cell))))
      (#/setTitle: prototype (native-string "Option"))
      (#/setButtonType: prototype #$NSRadioButton)
      (#/initWithFrame:mode:prototype:numberOfRows:numberOfColumns: (Native-View Self) Frame #$NSRadioModeMatrix prototype (#/count (elements Self)) 1)
      (dotimes (i (#/count (elements Self)))
        (let ((element (#/objectAtIndex: (elements Self) i)))
          (#/putCell:atRow:column: (Native-View Self) element i 0))))))


(defmethod ADD-ITEM ((Self radio-button-control) text action)
  (let ((item (#/init (#/alloc ns:ns-button-cell))))
    (#/setTitle: item (native-string text))
    (#/setButtonType: item  #$NSRadioButton)   
    (setf (actions Self) (append (actions Self) (list action)))
    (setf (elements Self) (#/arrayByAddingObject: (elements Self) item))))


;__________________________________
; IMAGE BUTTON CLUSTER CONTROL     |
;__________________________________/

(defmethod INITIALIZE-INSTANCE :after ((Self radio-button-control) &rest Args)
  (declare (ignore Args))
  (setf (elements self) (#/init (#/alloc ns:ns-mutable-array)))
  (call-next-method))


;__________________________________
; Popup Button                     |
;__________________________________/

(defclass native-popup-button (ns:ns-pop-up-button)
  ((lui-view :accessor lui-view :initarg :lui-view))
  (:metaclass ns:+ns-object))


(defmethod make-native-object ((Self popup-button-control))
  (let ((Native-Control (make-instance 'native-popup-button :lui-view Self)))
    (ns:with-ns-rect (Frame (x self) (y Self) (width Self) (height Self))
      (#/initWithFrame:pullsDown: Native-Control Frame #$NO)
      ;(#/setControlSize: (#/cell native-control)  #$NSMiniControlSize)
    Native-Control)))


(defmethod VALUE ((self popup-button-control))
  (#/title (#/selectedItem (native-view self))))


(defmethod GET-SELECTED-ACTION ((Self popup-button-control))
  (elt (actions self)  (#/indexOfSelectedItem (native-view self))))


(defmethod POPUP-ACTION ((window window) (self popup-Button-Control))
  (unless (eql (get-selected-action self) NIL)
    (let ((action (get-selected-action self)))
      (funcall action Window Self))))


(defmethod SET-SELECTED-ITEM-WITH-TITLE ((Self popup-button-control) text)
  (#/selectItemWithTitle: (native-view self) (native-string text)))


(defmethod ADD-ITEM ((Self popup-button-control) Text Action )
  (if (equal (#/indexOfItemWithTitle: (native-view Self) (native-string Text)) -1)
    (progn 
      (#/addItemWithTitle: (native-view Self) (native-string Text))
      (setf (actions Self) (append (actions Self) (list Action))))
    (warn "Cannot add item with the same title (~S)" Text)))


(defmethod ADD-NS-MENU-ITEM ((Self popup-button-control) Item)
  (if (equal (#/indexOfItemWithTitle: (native-view Self) (native-string (Text item))) -1)
    (progn   
      (#/addItem: (#/menu (native-view Self)) (native-view Item))
      (setf (actions Self) (append (actions Self) (list (Action item)))))
    (warn "Cannot add item with the same title (~S)" (Text item))))


;__________________________________
; Popup Image Button Item          |
;__________________________________/

(defclass native-popup-image-button-item (ns:ns-menu-item)
  ((lui-view :accessor lui-view :initarg :lui-view))
  (:metaclass ns:+ns-object))


(defmethod INVOKE-ACTION ((Self popup-image-button-item-control))  
  (funcall (action Self) (window (popup-image-button self)) (target Self)))


(defmethod make-native-object ((Self popup-image-button-item-control))
  (let ((Native-Control (make-instance 'native-popup-image-button-item :lui-view Self)))
    (#/initWithTitle:action:keyEquivalent: Native-Control (native-string (text self)) (objc::@selector #/activateAction) (native-string ""))
    Native-Control))


;__________________________________
; Popup Image Button Submenu       |
;__________________________________/

(defclass native-popup-image-button-submenu (ns:ns-menu)
  ((lui-view :accessor lui-view :initarg :lui-view))
  (:metaclass ns:+ns-object))


(defmethod initialize-event-handling ((Self popup-image-button-submenu-control))
  ;do nothing for now
  )


(defmethod make-native-object ((Self popup-image-button-submenu-control))
  (let ((Native-Control (make-instance 'native-popup-image-button-submenu :lui-view Self)))
    (#/initWithTitle: Native-Control (native-string (text self)) )
    (#/setAutoenablesItems: native-control #$NO)
    Native-Control))


;__________________________________
; Popup Image Button               |
;__________________________________/

(defclass native-popup-image-button (ns:ns-button)
  ((lui-view :accessor lui-view :initarg :lui-view))
  (:metaclass ns:+ns-object))


(defmethod make-native-object ((Self popup-image-button-control))
  (let ((Native-Control (make-instance 'native-popup-image-button :lui-view Self)))
    (ns:with-ns-rect (Frame (x self) (y Self) (width Self) (height Self))
      (let ((Path (native-path "lui:resources;buttons;" (image Self)))
            (NS-Image (#/alloc ns:ns-image))
            (disclosure-Image (#/alloc ns:ns-image)))
        (unless (probe-file Path) (error "no such image file for button ~A" (image Self)))
        (#/initWithContentsOfFile: NS-Image  (native-string (native-path "lui:resources;buttons;" (image Self))))
        (#/initWithContentsOfFile: disclosure-image  (native-string (native-path "lui:resources;buttons;" "disclosureDown4.png")))
        (#/setFlipped: disclosure-image #$YES)
        (#/setFlipped: ns-image #$YES)
        (setf (disclosure-image self) disclosure-image)
        (#/initWithFrame: Native-Control Frame)
        ;(#/setImageScaling: Native-Control 1)   
        (#/setButtonType: Native-Control #$NSOnOffButton)   ;;;NSMomentaryPushInButton)
        (#/setImagePosition: Native-Control #$NSImageOnly)
        (#/setImage: Native-Control NS-Image)
        (#/setBezelStyle: Native-Control #$NSShadowlessSquareBezelStyle)
        (#/setTitle: Native-Control (native-string (text Self))))
      (let ((Pop-up (make-instance 'popup-button-control :x 0 :y -20 )))  
        (#/setAutoenablesItems: (native-view pop-up) #$NO)
        (#/setTransparent: (native-view Pop-Up) #$YES)
        (setf (popup-button self) pop-up))
      Native-Control)))


(objc:defmethod (#/drawRect: :void) ((self native-popup-image-button) (rect :<NSR>ect))
  ;; if there is an error make this restartable from alternate console
  (if (draw-disclosure (lui-view self))
    (progn
      (ns:with-ns-rect (Frame (- (NS:NS-RECT-WIDTH rect) 10) 0 10 (NS:NS-RECT-HEIGHT rect))
        (#/drawInRect:fromRect:operation:fraction: (disclosure-image (lui-view self)) Frame #$NSZeroRect #$NSCompositeCopy 1.0))
      (ns:with-ns-rect (Frame 0 0 (- (NS:NS-RECT-WIDTH rect) 10)  (NS:NS-RECT-HEIGHT rect) )
        ;(call-next-method frame)
        (#/drawInRect:fromRect:operation:fraction: (#/image self) Frame #$NSZeroRect #$NSCompositeCopy 1.0)
        ))
    (#/drawInRect:fromRect:operation:fraction: (#/image self) rect #$NSZeroRect #$NSCompositeCopy 1.0)))


(defmethod POPUP-IMAGE-BUTTON-ACTION ((w window) (Button popup-image-button-control))
  (dotimes (i (length (items button)))
    (let ((item (#/itemAtIndex: (native-view (popup-button button))i)))
      (if (funcall (enable-predicate (elt (items button) i)) w (elt (items button) i))
        (#/setEnabled: item #$YES)
        (#/setEnabled: item #$NO))))
  (ns:with-ns-rect (Frame 0 0 10 10)
    (add-subviews button (popup-button button))
    (ns:with-ns-point (Point 0 0)    
      (let* ((event2 (#/alloc ns:ns-event))
             ;(item (#/selectedItem (native-view (popup-button button))))
             ; (action (#/action item))
             ; (target (#/action item))
             )        
        (#/trackMouse:inRect:ofView:untilMouseUp: (#/cell (native-view (popup-button button))) event2 (#/bounds (native-view (popup-button button))) (native-view (popup-button button)) #$NO)
        (#/setState: (#/cell (native-view (popup-button button))) #$NSOffState)
        #+cocotron
        (#/sendAction:to: (native-view (popup-button button)) (#/action (native-view (popup-button button))) (#/target (native-view (popup-button button))))
         (#/removeFromSuperview (native-view (popup-button button)))
        ))))


(defun SHOW-STRING-POPUP-FROM-ITEM-LIST (window item-list)
    (let ((Pop-up (make-instance 'popup-button-control )))
      (dolist (item item-list)
        (add-ns-menu-item Pop-Up item))
      (add-subviews window Pop-up)
      (#/setTransparent: (native-view Pop-Up) #$YES)
      (#/performClick:  (native-view Pop-up) +null-ptr+)
      (#/removeFromSuperview (native-view Pop-up))
      (ccl::lisp-string-from-nsstring  (#/titleOfSelectedItem (native-view Pop-Up)))
      ))


(defmethod ADD-POPUP-ITEM ((Self popup-image-button-control) Text Action predicate key-equivalent)
  (let ((item (make-instance 'popup-image-button-item-control  :text text :action action :popup-image-button self )))
    (if predicate
      (setf (enable-predicate item) predicate))
    (case (items self)
          (nil (setf (items self) (list item)))
          (t (setf (items self) (append (items self) (list item)))))
    ;(add-ns-menu-item (popup-button self) item)
    (add-item (popup-button self) text action)
    (if key-equivalent
      (#/setKeyEquivalent: (#/lastItem (native-view (popup-button self))) (native-string key-equivalent)))
    ;(#/addItem: (menu self) (native-view item) )
    ))


(defmethod ADD-POPUP-SUBMENU ((Self popup-image-button-control) Text action predicate )
  (declare (ignore  predicate))
  (let ((menu (make-instance 'popup-image-button-submenu-control)))
    (add-item (popup-button self) text action)
    ;(#/addItemWithTitle:action:keyEquivalent: (native-view menu) (native-string "SUB MENU ITEM 1") (objc::@selector #/activateAction) (native-string ""))
    (#/setSubmenu: (#/itemWithTitle: (native-view (popup-button self)) (native-string text)) (native-view menu))
    ))


(defmethod ADD-POPUP-SUBMENU2 ((Self popup-image-button-control) Menu text action predicate)
  (declare (ignore  predicate))
    (add-item (popup-button self) text action)
    ;(#/addItemWithTitle:action:keyEquivalent: (native-view menu) (native-string "SUB MENU ITEM 1") (objc::@selector #/activateAction) (native-string ""))
    (#/setSubmenu: (#/itemWithTitle: (native-view (popup-button self)) (native-string text)) (native-view menu))
    )

(defmethod ADD-SUBMENU-TO-SUBMENU ((Self popup-image-button-submenu-control) new-menu text action predicate)
  (declare (ignore  text action predicate))
  (#/addItemWithTitle:action:keyEquivalent: (native-view self) (native-string (text new-menu)) (objc::@selector #/activateAction)(native-string ""))
  ;(#/addItemWithTitle:action:keyEquivalent: (native-view menu) (native-string "SUB MENU ITEM 1") (objc::@selector #/activateAction) (native-string ""))
  (#/setSubmenu: (#/itemWithTitle: (native-view self) (native-string (text new-menu))) (native-view new-menu))
  )


(defmethod ADD-ITEM-TO-SUBMENU ((Self popup-image-button-submenu-control) Text action predicate)
  (declare (ignore action predicate))
  (#/addItemWithTitle:action:keyEquivalent: (native-view self) (native-string text) (objc::@selector #/activateAction) (native-string ""))
  ;   (#/setSubmenu: (#/itemWithTitle: (native-view (popup-button self)) (native-string text)) menu)
  )

;__________________________________
; Choice Button                   |
;__________________________________/

(defclass native-choice-button (ns:ns-pop-up-button)
  ((lui-view :accessor lui-view :initarg :lui-view))
  (:metaclass ns:+ns-object))


(defmethod make-native-object ((Self choice-button-control))
  (let ((Native-Control (make-instance 'native-choice-button :lui-view Self)))
    (ns:with-ns-rect (Frame (x self) (y Self) (width Self) (height Self))
      (#/initWithFrame:pullsDown: Native-Control Frame #$NO)
    Native-Control)))


(defmethod VALUE ((self choice-button-control))
  (ccl::lisp-string-from-nsstring(#/title (#/selectedItem (native-view self)))))


(defmethod GET-SELECTED-ACTION ((Self choice-button-control))
  (elt (actions self)  (#/indexOfSelectedItem (native-view self))))


(defmethod CHOICE-BUTTON-ACTION ((window window) (self choice-button-Control))
  (let ((action (get-selected-action self)))
    (funcall action Window Self)))


(defmethod ADD-MENU-ITEM ((Self choice-button-control) text action Image-pathname)
  (#/addItemWithTitle: (native-view Self) (native-string text))
  (unless (equal image-pathname nil)
    (let ((image (#/alloc ns:ns-image)))
          (#/initWithContentsOfFile: image (native-string (native-path "lui:resources;" image-pathname)))
          (#/setImage: (#/itemWithTitle: (native-view Self) (native-string text)) Image)))
  (setf (actions Self) (append (actions Self) (list Action))))

;__________________________________
; Seperator                        |
;__________________________________/

(defclass native-seperator (ns:ns-box)
  ((lui-view :accessor lui-view :initarg :lui-view))
  (:metaclass ns:+ns-object))


(defmethod make-native-object ((Self seperator-control))
  (let ((Native-Control (make-instance 'native-seperator :lui-view Self)))
    (ns:with-ns-rect (Frame (x self) (y Self) (width Self) (height Self))
      (#/initWithFrame: Native-Control Frame)
      (#/setBorderType: Native-Control #$NSLineBorder)
      (#/setBoxType: Native-Control #$NSBoxSeparator)
      Native-Control)))


(defmethod (setf text) :after (Text (Self seperator-control))
  (#/setTitle: (native-view Self) (native-string Text)))

;__________________________________
; SLIDER                           |
;__________________________________/

(defclass native-slider (ns:ns-slider)
  ((lui-view :accessor lui-view :initarg :lui-view))
  (:metaclass ns:+ns-object))


(defmethod make-native-object ((Self slider-control))
  (let ((Native-Control (make-instance 'native-slider :lui-view Self)))
    (ns:with-ns-rect (Frame (x self) (y Self) (width Self) (height Self))
      (#/initWithFrame: Native-Control Frame)
      (#/setMinValue: Native-Control (float (min-value Self) 0d0))
      (#/setMaxValue: Native-Control (float (max-value Self) 0d0))
      (#/setNumberOfTickMarks: Native-Control (truncate (tick-marks Self)))
      #-cocotron (#/setTitle: Native-Control (native-string (text Self)))  ;; depreciated: use separate label
      ;; Make sure the slider's indicator/thumb is positioned properly based on
      ;; control's initial value
      (#/setFloatValue: Native-Control (slot-value Self 'value)))
    Native-Control))

(defmethod (setf VALUE)  (Value (Self slider-control))
  (#/setFloatValue: (native-view Self) Value))

(defmethod VALUE ((Self slider-control))
  (#/floatValue (native-view Self)))

;__________________________________
; LABEL                            |
;__________________________________/

(defclass native-label (ns:ns-text-view)
  ((lui-view :accessor lui-view :initarg :lui-view))
  (:metaclass ns:+ns-object))


(defmethod make-native-object ((Self label-control))
  (let ((Native-Control (make-instance 'native-label :lui-view Self)))  ;; NSText is not actually a control, would NSTextField be better?
    (ns:with-ns-rect (Frame (x self) (y Self) (width Self) (height Self))
      (#/initWithFrame: Native-Control Frame)
      (#/setDrawsBackground: Native-Control nil)
      (#/setString: Native-Control (native-string (text Self)))
      (ecase (align Self)
        (:left (#/alignLeft: Native-Control Native-Control))
        (:center (#/alignCenter: Native-Control Native-Control))
        (:right (#/alignRight: Native-Control Native-Control))
        (:justified (#/alignJustified: Native-Control Native-Control)))
      (#/setEditable: Native-Control #$NO)
      (#/setSelectable: Native-Control #$NO) )
    Native-Control))


(defmethod (setf text) :after (Text (Self label-control))
  (#/setString: (native-view Self) (native-string Text)))

;__________________________________
; Editable TEXT                    |
;__________________________________/

(defclass native-editable-text (ns:ns-text-field)
  ((lui-view :accessor lui-view :initarg :lui-view))
  (:metaclass ns:+ns-object))


(defmethod make-native-object ((Self editable-text-control))
  (let ((Native-Control (make-instance 'native-editable-text :lui-view Self)))
    (ns:with-ns-rect (Frame (x self) (y Self) (width Self) (height Self))
      (#/initWithFrame: Native-Control Frame)
      (#/setDrawsBackground: Native-Control nil)
      (#/setStringValue: Native-Control (native-string (text Self)))
      #| (ecase (align Self)
        (:left (#/alignLeft: Native-Control Native-Control))
        (:center (#/alignCenter: Native-Control Native-Control))
        (:right (#/alignRight: Native-Control Native-Control))
        (:justified (#/alignJustified: Native-Control Native-Control))) |# )  
    Native-Control))


(defmethod (setf text) :after (Text (Self editable-text-control))
  (#/setStringValue: (native-view Self) (native-string Text)))


(defmethod VALUE ((Self editable-text-control))
  (ccl::lisp-string-from-nsstring 
   (#/stringValue (native-view Self))))

(defmethod (setf VALUE)  (Text (Self editable-text-control))
  (#/setStringValue: (native-view Self) (native-string Text)))


(defmethod MAP-SUBVIEWS ((Self editable-text-control) Function &rest Args)
  (declare (ignore Function Args))
  ;; no Cocoa digging
  )


(defmethod SUBVIEWS ((Self editable-text-control))
  ;; no Cocoa digging
  )


;__________________________________
; STATUS BAR                   |
;__________________________________/

(defclass native-status-bar (ns:ns-text-field)
  ((lui-view :accessor lui-view :initarg :lui-view))
  (:metaclass ns:+ns-object))


(defmethod make-native-object ((Self status-bar-control))
  (let ((Native-Control (make-instance 'native-status-bar :lui-view Self)))
    (ns:with-ns-rect (Frame (x self) (y Self) (width Self) (height Self))
      (#/initWithFrame: Native-Control Frame)
      (#/setDrawsBackground: Native-Control #$NO)
      (#/setEditable: Native-Control #$NO)
      (#/setBezeled: Native-Control #$NO)
      (#/setStringValue: Native-Control (native-string (text Self)))
      #| (ecase (align Self)
        (:left (#/alignLeft: Native-Control Native-Control))
        (:center (#/alignCenter: Native-Control Native-Control))
        (:right (#/alignRight: Native-Control Native-Control))
        (:justified (#/alignJustified: Native-Control Native-Control))) |# )  
    Native-Control))


(defmethod (setf text) :after (Text (Self status-bar-control))
  (#/setStringValue: (native-view Self) (native-string Text)))


(defmethod VALUE ((Self status-bar-control))
  (ccl::lisp-string-from-nsstring 
   (#/stringValue (native-view Self))))

(defmethod (setf VALUE)  (Text (Self status-bar-control))
  (#/setStringValue: (native-view Self) (native-string Text)))


(defmethod MAP-SUBVIEWS ((Self status-bar-control) Function &rest Args)
  (declare (ignore Function Args))
  ;; no Cocoa digging
  )


(defmethod SUBVIEWS ((Self status-bar-control))
  ;; no Cocoa digging
  )

;__________________________________
; Progress Indicator               |
;__________________________________/

(defclass native-progress-indicator-control (ns:ns-progress-indicator)
  ((lui-view :accessor lui-view :initarg :lui-view))
  (:metaclass ns:+ns-object))

(defmethod make-native-object ((Self progress-indicator-control))
  (let ((Native-Control (make-instance 'native-progress-indicator-control :lui-view Self)))
    (ns:with-ns-rect (Frame (x self) (y Self) (width Self) (height Self))
      (#/initWithFrame: Native-Control Frame)
      (#/setIndeterminate: Native-Control #$YES))
  Native-Control))

(defmethod initialize-event-handling ((Self progress-indicator-control))
  (declare (ignore self)))

(defmethod START-ANIMATION ((self progress-indicator-control))
  (#/startAnimation: (native-view self) (native-view self)))


(defmethod STOP-ANIMATION ((self progress-indicator-control))
  (#/stopAnimation: (native-view self) (native-view self)))
    
;__________________________________
; Determinate Progress Indicator   |
;__________________________________/

(defclass native-determinate-progress-indicator-control (ns:ns-progress-indicator)
  ((lui-view :accessor lui-view :initarg :lui-view))
  (:metaclass ns:+ns-object))

(defmethod make-native-object ((Self determinate-progress-indicator-control))
  (let ((Native-Control (make-instance 'native-determinate-progress-indicator-control :lui-view Self)))
    (ns:with-ns-rect (Frame (x self) (y Self) (width Self) (height Self))
      (#/initWithFrame: Native-Control Frame)
      (#/setIndeterminate: Native-Control #$NO)
      (#/setMinValue: Native-Control (min-value self))
      (#/setMaxValue: Native-Control (max-value self)))
  Native-Control))


(defmethod initialize-event-handling ((Self determinate-progress-indicator-control))
  (declare (ignore self)))


(defmethod INCREMENT-BY ((self determinate-progress-indicator-control) double)
  "This mthod will increment the determinate progress indicator by the given amount double"
  (#/incrementBy: (native-view self) double))

       
;__________________________________
; IMAGE                            |
;__________________________________/

(defclass native-image (ns:ns-image-view)
  ((lui-view :accessor lui-view :initarg :lui-view))
  (:metaclass ns:+ns-object))


(defmethod make-native-object ((Self image-control))
  (let ((Native-Control (make-instance 'native-image :lui-view Self))) 
      ;; no problem if there is no source, just keep an empty view
      (cond
       ;; in most cases there should be an image source
       ((src Self)
        ;; consider caching image with the same file, there is a good chance
        ;; that some image files, e.g., buttons are used frequently
        (let ((Image #-cocotron (#/initByReferencingFile: (#/alloc ns:ns-image) (native-string (source Self)))
                     #+cocotron (#/initWithContentsOfFile: (#/alloc ns:ns-image) (native-string (source Self)))))
          (unless #-cocotron (#/isValid Image)
                  #+cocotron (not (ccl:%null-ptr-p Image))
            (error "cannot create image from file ~S" (source Self)))
          ;; if size 0,0 use original size
          (when (and (zerop (width Self)) (zerop (height Self)))
            (let ((Size (#/size Image)))
              (setf (width Self) (rref Size <NSS>ize.width))
              (setf (height Self) (rref Size <NSS>ize.height))))
          (ns:with-ns-rect (Frame (x self) (y Self) (width Self) (height Self))
            (#/initWithFrame: Native-Control Frame))
          (#/setImage: Native-Control Image)
          (if (scale-proportionally self)
            (#/setImageScaling: Native-Control #$NSScaleProportionally)
            (#/setImageScaling: Native-Control #$NSScaleToFit))))
       (t
        (ns:with-ns-rect (Frame (x self) (y Self) (width Self) (height Self))
              (#/initWithFrame: Native-Control Frame))))
      Native-Control))


(defmethod change-image ((self image-control) image-name)
  (setf (src self) image-name)
  (let ((Image #-cocotron (#/initByReferencingFile: (#/alloc ns:ns-image) (native-string (source Self)))
               #+cocotron (#/initWithContentsOfFile: (#/alloc ns:ns-image) (native-string (source Self)))))
    (unless #-cocotron (#/isValid Image)
      #+cocotron (not (ccl:%null-ptr-p Image))
      (error "cannot create image from file ~S" (source Self)))
    ;; if size 0,0 use original size
    (when (and (zerop (width Self)) (zerop (height Self)))
      (let ((Size (#/size Image)))
        (setf (width Self) (rref Size <NSS>ize.width))
        (setf (height Self) (rref Size <NSS>ize.height))))
    (#/setImage: (Native-view self) Image)
    (#/setNeedsDisplay: (native-view self) #$YES)))


;__________________________________
; Color Well                       |
;__________________________________/

(defclass NATIVE-COLOR-WELL (ns:ns-color-well)
  ((lui-view :accessor lui-view :initarg :lui-view))
  (:metaclass ns:+ns-object))


(defmethod MAKE-NATIVE-OBJECT ((Self color-well-control))
  (let ((Native-Control (make-instance 'native-color-well :lui-view Self)))
    (ns:with-ns-rect (Frame (x self) (y Self) (width Self) (height Self))
      (multiple-value-bind (Red Blue Green)
                           (parse-rgb-from-hex self (color self))
        ;(setf (color self) (concatenate (write-to-string Red) (write-to-string 
        (let ((nscolor (#/colorWithDeviceRed:green:blue:alpha: ns:ns-color (/ red 255.0) (/ blue 255.0) (/ green 255.0)  1.0 )))                
          (#/initWithFrame: Native-Control Frame)
          (#/setColor: Native-Control nscolor)))
      ;; setup alpha control but keep in mind color panel is shared -> cannot mix alpha / no alpha
      (#/setShowsAlpha: (#/sharedColorPanel ns:ns-color-panel) (if (show-alpha Self) #$YES #$NO))
      Native-Control)))


(defmethod PARSE-RGB-FROM-HEX ((Self color-well-control) string)
  (values
   (read-from-string (concatenate 'string "#x" (subseq string 0 2)))   ;Red
   (read-from-string (concatenate 'string "#x" (subseq string 2 4)))   ;Blue
   (read-from-string (concatenate 'string "#x" (subseq string 4 6))))) ;Green


(defmethod GET-RED ((self color-well-control))
  (rlet ((r #>CGFloat)
         (g #>CGFloat)
         (b #>CGFloat)
         (a #>CGFloat))
    (#/getRed:green:blue:alpha: (#/color (Native-View self)) r g b a)
    (truncate (* (pref r #>CGFloat) 255))))


(defmethod GET-GREEN ((self color-well-control))
  (rlet ((r #>CGFloat)
         (g #>CGFloat)
         (b #>CGFloat)
         (a #>CGFloat))
    (#/getRed:green:blue:alpha: (#/color (Native-View self)) r g b a)
    (truncate (* (pref g #>CGFloat) 255))))


(defmethod GET-BLUE ((self color-well-control))
  (rlet ((r #>CGFloat)
         (g #>CGFloat)
         (b #>CGFloat)
         (a #>CGFloat))
    (#/getRed:green:blue:alpha: (#/color (Native-View self)) r g b a)
    (truncate (* (pref b #>CGFloat) 255))))


(defmethod GET-ALPHA ((self color-well-control))
  (rlet ((r #>CGFloat)
         (g #>CGFloat)
         (b #>CGFloat)
         (a #>CGFloat))
    (#/getRed:green:blue:alpha: (#/color (Native-View self)) r g b a)
    (truncate (* (pref a #>CGFloat) 255))))


(defmethod SET-COLOR ((Self color-well-control) &key (Red 0.0) (Green 0.0) (Blue 0.0) (Alpha 1.0))
  ;; keep a native color instead of creating a new one for each display
  (#/setColor: (native-view Self) (#/retain (#/colorWithCalibratedRed:green:blue:alpha: ns:ns-color Red Green Blue Alpha))))

;__________________________________
; Web Browser                      |
;__________________________________/

#| Takes a long time to load: disable for now

#-cocotron
(eval-when (:compile-toplevel :load-toplevel :execute)
  (objc:load-framework "WebKit" :webkit))


#-cocotron
(progn
(defclass native-web-browser (ns:web-view)
  ((lui-view :accessor lui-view :initarg :lui-view))
  (:metaclass ns:+ns-object))


(defmethod make-native-object% ((Self web-browser-control))
 (ns:with-ns-rect (Frame (x self) (y Self) (width Self) (height Self))
                        ;; code borrowed from Clozure/Webkit.lisp
                        (let ((Native-Control (make-instance 'native-web-browser
                                                :with-frame Frame
                                                :frame-name #@"frame"
                                                :group-name #@"group"
                                                :lui-view Self)))
                          ;; Start a URL request.  The request is processed
                          ;; asynchronously, but apparently needs to be initiated
                          ;; from the event-handling thread.
                          (let* ((webframe (#/mainFrame Native-Control))
                                 (request (#/requestWithURL:
                                           ns:ns-url-request
                                           (ccl::with-autorelease-pool
                                               (#/retain (#/URLWithString: ns:ns-url (ccl::%make-nsstring (string (url Self)))))))))
                            ;; Failing to wait until the main thread has
                            ;; initiated the request seems to cause
                            ;; view-locking errors.  Maybe that's just
                            ;; an artifact of some other problem.
                            (#/performSelectorOnMainThread:withObject:waitUntilDone:
                             webframe (ccl::@selector #/loadRequest:) request t)
                            Native-Control))))


(defmethod make-native-object ((Self web-browser-control))
 (let* ((ip ccl::*initial-process*))
   (if (eq ccl::*current-process* ip)
     (make-native-object% self)
     (let* ((s (make-semaphore))
            (v nil))
       (process-interrupt ip (lambda ()
                               (setq v (make-native-object% self))
                               (signal-semaphore s)))
       (wait-on-semaphore s)
       v))))

(export '(load-url))

(defmethod LOAD-URL ((Self web-browser-control) url)
  (let* ((webframe (#/mainFrame (Native-View Self)))
         (request (#/requestWithURL:
                   ns:ns-url-request
                   (ccl::with-autorelease-pool
                       (#/retain (#/URLWithString: ns:ns-url (ccl::%make-nsstring (string url ))))))))
    ;; Failing to wait until the main thread has
    ;; initiated the request seems to cause
    ;; view-locking errors.  Maybe that's just
    ;; an artifact of some other problem.
    (#/performSelectorOnMainThread:withObject:waitUntilDone:
     webframe (ccl::@selector #/loadRequest:) request t)
    ))
  
(defmethod MAP-SUBVIEWS ((Self web-browser-control) Function &rest Args)
  (declare (ignore Function Args))
  ;; no DOM digging
  )


(defmethod SUBVIEWS ((Self web-browser-control))
  ;; no DOM digging
  )

;; only for the sake of exploration: can't really get into the DOM: stuck at WebHTMLView

(defun print-dom (View &optional (Level 0))
  (let ((Subviews (#/subviews View)))
    (dotimes (i (#/count Subviews))
      (dotimes (i Level) (princ "  "))
      (let ((Subview (#/objectAtIndex: Subviews i)))
        (format t "~A~%" Subview)
        (print-dom Subview (1+ Level))))))

;; (lui::print-dom (lui::native-view <web-browser url="http://www.agentsheets.com"/>))
)

|#

;__________________________________
; Show PopUp                       |
;__________________________________/

(defun SHOW-STRING-POPUP (window list &key selected-item container item-addition-action-string-list) 
  (let ((Pop-up (make-instance 'popup-button-control  :container container :width 1 :height 1 :x   (- (rational (NS:NS-POINT-X (#/mouseLocation ns:ns-event)))(x window))  :y   (-  (- (NS:NS-RECT-HEIGHT (#/frame (#/mainScreen ns:ns-screen)))(NS:NS-POINT-Y (#/mouseLocation ns:ns-event)))(y window))  )))
    (dolist (String list)
      (add-item Pop-Up String nil))
    (if item-addition-action-string-list
      (add-item Pop-Up (first item-addition-action-string-list) (second item-addition-action-string-list)))
    (add-subviews window Pop-up)
    (when selected-item
      (#/selectItemWithTitle: (native-view pop-up) (native-string selected-item)))
    (#/setTransparent: (native-view Pop-Up) #$YES)
    (#/performClick:  (native-view Pop-up) +null-ptr+)
    (#/removeFromSuperview (native-view Pop-up))
    (ccl::lisp-string-from-nsstring  (#/titleOfSelectedItem (native-view Pop-Up)))))

