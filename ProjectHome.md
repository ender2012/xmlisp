e<b>X</b>reme <b>M</b>edia <b>Lisp</b>: A rich media programming environment for 3D/ 2D game and simulation applications.

  * <b>3D:</b> Open Agent Engine: scene graph based mini engine, 3D objects, animation, drag and drop, mouse hovering, picking, selection, camera control, texture management. Full access to OpenGL functions including shaders (GLSL).
  * <b>2D:</b> controls: layout managers, buttons, sliders, text
  * <b>Media:</b> Sound, Text-to-Speech (OS X only)
  * <b>Events:</b> mouse, keyboard, multi touch, gestures (OS X 10.6 and later): pinch, rotate, scroll
  * <b>IDE</b> a simple development environment including symbol completion to edit, run and debug code

![http://www.agentsheets.com/images/XMLisp_screen.png](http://www.agentsheets.com/images/XMLisp_screen.png)


XMLisp simulations and animations run as fast compiled code in native threads. Run multiple simulations at the same time, resize windows, move windows, move the camera, browse web pages, .... your simulation continues  as smooth as possible.

### What is New? Version 0.5 ###
  * First release of XMLISP Windows Alpha based on CCL Version 1.7-dev-r14645M-trunk.
  * Known issues for the alpha are listed on the wiki: http://code.google.com/p/xmlisp/wiki/XMLisp

### What is New? Version 0.4 ###
  * based on CCL 1.6 (1.6-r14468M)
  * Vertex and Fragment GLSL Shader support including example
  * NeHe OpenGL example folder including example
  * new controls classes
  * keyboard event support
  * trackpad gesture support: pinch, rotate, scroll (OS X 10.6 and later)
  * cursor support including example

Known issues: Web browsers only work in 32bit (webkit bug) version

### What is New? Version 0.3.5 ###
  * works on OS X 10.5 and 10.6 (Snow Leopard)
  * based on CCL 1.5 (1.5-rc1-[r13616](https://code.google.com/p/xmlisp/source/detail?r=13616))
  * new examples

### What is New? Version 0.3 ###
  * drag and drop: drag and drop 3D agents within or between windows. Sample: Drag and Drop gearbox
  * morphs: static meshes and animated morph meshes. Sample: Mona-Lisa Morph
  * full screen support: switch between windowed and full screen mode. Sample: Full-Screen-Support
  * 3D text support
  * custom cursors (working also for 64 bit)
  * transparent OpenGL windows (for annotation and drag and drop)
  * support of shared OpenGL contexts
  * camera can be added to scene via XML, <camera eye-x="0.5" .../>
  * various bug fixes and improvements including fast agent picking, vertically flipped textures

### Philosophy ###
Conceptually the 3D part of XMLisp, that is the Open Agent Engine, is somewhere between scene graph (e.g., Java3D) and direct mode rendering (JOGL). Simple applications consist of a tree structure of agents such as cubes, planes, and spheres.  No OpenGL code needs to be written for these. But if you need specialized rendering you create subclasses of agents and extend their draw method using OpenGL calls from basic polygons to shaders.


### Getting Started ###
In less than 5 minutes...
  * download & launch the application
  * open any of the files in the examples folder. The <b>Lisp > Execute All</b> menu command will load, compile and run the example
  * use modifier keys to control camera: control=rotate, option/alt=zoom, command=pan

### Moving Ahead: DIY ###
  * use or subclass <b>application-window</b>
  * use or subclass <b>agent-3D-view</b>
  * use or subclass <b>agent-3D</b> classes (e.g., cube, sphere, cylinder, disk, tile)
  * use or subclass 2D classes (e.g, button, slider)
  * define <b>animate</b> methods
  * for custom agents define <b>draw</b> methods calling OpenGL functions
  * if there are controls such as buttons with actions implement them as methods
  * define GUI + scene in XML

### Example 1: Basic Cocoa Drawing ###
A simple 2D example based on Cocoa drawing functions is to define a subclass of view and implement its <b>draw</b> method:

```
(defmethod DRAW ((Self rectangle-view))
  (when (native-color Self)
    (#/set (native-color Self)))
  (ns:with-ns-rect (Frame 0.0 0.0 (width Self) (height Self))
    (#_NSRectFill Frame)))
```

Now create a window and put this simple but boring colored rectangle in it:,
```
(add-subviews
 (make-instance 'window)
 (make-instance 'rectangle-view))
```

[complete example](http://code.google.com/p/xmlisp/source/browse/trunk/XMLisp/sources/Lisp%20User%20Interface/specific/Mac%20CCL/LUI%20Cocoa.lisp#321)

### Example 2: Basic OpenGL Drawing ###
For OpenGL drawing subclass <b>opengl-view</b> and implement its <b>draw</b> method.

```
(in-package :lui)

(defclass CIRCLE-VIEW (opengl-view)
  ((radius :accessor radius :initform 1.0 :type float)
   (slices :accessor slices :initform 10 :type integer :initarg :slices)))


(defmethod PREPARE-OPENGL ((Self circle-view))
  ;; this code gets called only once before drawing for the first time
  (glColor3f 1.0 0.0 0.0))


(defmethod DRAW ((Self circle-view))
  (let ((delta (/ (* (float pi 0.0) 2.0) (slices Self))))
    (glBegin GL_LINE_LOOP)
    (dotimes (i (slices Self))
      (let ((angle (* i delta)))
        (glVertex2f (* (cos angle) (radius Self)) (* (sin angle) (radius Self)))))
    (glEnd)))


(add-subviews
 (make-instance 'window :width 180 :height 180 :title "crappy circle")
 (make-instance 'circle-view :width 180 :height 180 :slices 8))
```

![http://www.agentsheets.com/images/crappy_circle.png](http://www.agentsheets.com/images/crappy_circle.png)


### Example 3: Layout and Communication ###
More realistic applications need multiple controls/views, need to lay them out, and need to establish communication between them. At the XLUI level, a package using the :lui package,  sophisticated layout (horizontally, vertically, stretching, centering, ...) can easily be established. Each control and view class is wrapped up with XML serialization/deserialization and layout functions.

This example includes our "crappy" circle again but also features a slider to control the number of slices. The window, when resized, will keep a certain layout. Both, the circle-view and the slider, will stretch horizontally but only the circle view will stretch (vflex="1"). A slider action (action="adjust-slices-action" ) is used to update the number of slices of the circle view.

Notice differences from example 2: this code is in the :xlui package; circle-view is a subclass of <b>opengl-dialog</b>.


```
(in-package :xlui)

(defclass CIRCLE-VIEW (opengl-dialog)
  ((radius :accessor radius :initform 1.0 :type float)
   (slices :accessor slices :initform 3 :type integer)))


(defmethod PREPARE-OPENGL ((Self circle-view))
  ;; this code will run once before the first drawing
  (glColor3f 1.0 0.0 0.0))


(defmethod DRAW ((Self circle-view))
  (let ((delta (/ (* (float pi 0.0) 2.0) (slices Self))))
    (glBegin GL_LINE_LOOP)
    (dotimes (i (slices Self))
      (let ((angle (* i delta)))
        (glVertex2f (* (cos angle) (radius Self)) (* (sin angle) (radius Self)))))
    (glEnd)))


(defmethod ADJUST-SLICES-ACTION ((Window application-window) (Slider slider))
  (setf (slices (view-named Window "crappy circle")) (truncate (value Slider)))
  (display (view-named Window "crappy circle")))


<application-window title="circle, really?" y="50">
  <column align="stretch" valign="stretch">>
    <circle-view name="crappy circle" vflex="1"/>
    <slider action="adjust-slices-action" min-value="3.0" max-value="14.0" tick-marks="12"/>
  </column>
</application-window>

```


![http://www.agentsheets.com/images/adjustable_circle.png](http://www.agentsheets.com/images/adjustable_circle.png)


### Example 4: Scene Graphs (Chopper) ###
Here is a [complete example](http://code.google.com/p/xmlisp/source/browse/trunk/XMLisp/sources/XLUI/examples/3D/agents/Apocalypse%20Now.lisp) of the Chopper window above. Spinning rotors and body part are composed into a Chopper group which itself is moving in the wind (translational and rotational noise).  Note XML and Lisp code live in the same file.

Subclassing application-window
```

(defclass GAME-WINDOW (application-window)
  ())
```

Subclassing <b>tile</b> as <b>rotor</b> and defining <b>animation</b> method
```

(defclass ROTOR (tile) 
  ((rotor-speed :accessor rotor-speed :initform 90.0 :type float :documentation "degrees/sec")))


(defmethod ANIMATE ((Self rotor) Time)
  (setf (roll Self) (mod (+ (roll Self) (* Time (rotor-speed Self))) 360.0)))
```

Subclassing <b>group</b> as <b>chopper</b>
```
(defclass CHOPPER (group)
  ())

```
Defining shake in the wind <b>animation</b> method using random noise with  [discrete low pass filter](http://en.wikipedia.org/wiki/Low-pass_filter#Discrete-time_realization)
```
(defmethod ANIMATE ((Self chopper) dt)
  ;; noise functions with low pass filters are used to shake the chopper gently
  (let* ((Alpha (/ dt (+ dt 5.0)))
         (1-Alpha (- 1 Alpha)))
    (setf (x Self) (+ (* Alpha (- (random 10.0) 5.0)) (* 1-Alpha (x self))))
    (setf (y Self) (+ (* Alpha (- (random 10.0) 5.0)) (* 1-Alpha (y self))))
    (setf (z Self) (+ (* Alpha (- (random 10.0) 5.0)) (* 1-Alpha (z self))))
    (setf (heading Self) (+ (* Alpha (- (random 100.0) 50.0)) (* 1-Alpha (heading Self))))
    (setf (pitch Self) (+ (* Alpha (- (random 100.0) 50.0)) (* 1-Alpha (pitch Self))))
    (setf (roll Self) (+ (* Alpha (- (random 100.0) 50.0)) (* 1-Alpha (roll Self))))
    (call-next-method)))

```

Defining <b>start</b> and <b>stop</b> button actions as methods of <b>game-window</b>
```

(defmethod START ((Window game-window) (button bevel-button))
  (start-animation (view-named Window "war")))


(defmethod STOP ((Window game-window) (button bevel-button))
  (stop-animation (view-named Window "war")))
```
Laying out GUI with <b>row</b> and <b>column</b> layout managers. Scene graph is attached to <b>agent-3D-view</b> OpenGL view. Layout is defined to scale OpenGL view and to center the simulation control buttons. All the element names are simply the names of your Lisp classes. The element attributes correspond to the slot names of your classes. Slot :type information is used automatically serialize/de-serialize slot values, e.g. boolean values t/nil turn into "true"/"false"

XML is used to easily serialize/de-serialize scenes into files. XML content is usually much simpler to integrate with other tools. For most simple cases you will not have to worry about XML. You simply define your classes. The Common Lisp MOP will automagically turn your CLOS objects into XML expression and vice versa.

```
<game-window title="Choppers" track-mouse="true" margin="0">
  <column align="stretch" valign="stretch">
    <agent-3d-view name="war" vflex="1">
      <chopper>
        <group pitch="-90" x="-1.0">
          <rotor rotor-speed="360.0" width="5.0" height="0.2" x-turn="2.5" y-turn="0.1" texture="metal1.jpg"/>
        </group>
        <cube x="1.0" y="-1.3" z="-0.5" texture="metal1.jpg"/>
        <cylinder x="2.0" y="-0.8" heading="90" base-radius="0.3" top-radius="0.1" height="2.0" texture="metal1.jpg"/>
        <rotor rotor-speed="720.0" x="3.5" y="-0.8" z="0.2"  width="1.0" height="0.1" x-turn="0.5" y-turn="0.05" texture="metal1.jpg"/>
      </chopper>
      <sky-dome pitch="90"/>
    </agent-3d-view>
    <row minimize="vertical" align="center">
      <bevel-button text="start" action="start" width="55"/>
      <bevel-button text="stop" action="stop" width="55"/>
    </row>
  </column>
</game-window>


```

### Applications ###
  * education: use for you computer graphics class, e.g., following OpenGL Red Book
  * computational science: write your own 2D/3D models

### Implementation ###
  * XMLisp is a [Clozure Common Lisp](http://www.clozure.com) application
  * The Clozure CL editor is still in an early stage. Please be patient. If you find bugs and other annoying behaviors please submit a [new issue](http://code.google.com/p/xmlisp/issues/entry) or contact the authors.

### Status ###
  * Most of the original engine still missing. The original engine was written for MCL (OS X) and Allegro (Win).
  * XMLisp does not include header files. If you need to write your own Cocoa, Carbon, etc. code and not just Common Lisp and OpenGL you should download Clozure CL and load the sources.

### See Also ###
To see the more complete version of the engine in action watch this movie. [Mr. Vetro](http://www.agentsheets.com/research/c5/index.html) is a project funded by National Institutes of Health (NIH) and the National Science Foundation (NSF). The video shows complex real time image warping. The lung and heart are based on original illustrations from Gray's Anatomy.

> <a href='http://www.youtube.com/watch?feature=player_embedded&v=39NJJC1Vt18' target='_blank'><img src='http://img.youtube.com/vi/39NJJC1Vt18/0.jpg' width='425' height=344 /></a>

## References ##
  * Ioannidou, A., Repenning, A. and Webb, D.,  [AgentCubes: Incremental 3D end-user development,](http://www.cs.colorado.edu/~ralex/papers/PDF/AgentCubes_JVLC_article_inpress.pdf) Journal of Visual Language and Computing (2009), (XMLisp is used to build AgentCubes)
  * Repenning, A. and Ioannidou, A., [X-expressions in XMLisp: S-expressions and Extensible Markup Language Unite](http://www.cs.colorado.edu/~ralex/papers/PDF/X-expressions.pdf) , in Proceedings of the International Lisp Conference (ILC 2007), (Cambridge, England, 2007), (This paper explains the connection between Lisp and XML.)
