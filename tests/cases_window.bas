'Cases: primitives, text, repaint of windows and thin strips, incremental operations.
SUB RunAll
'1. The rewritten primitives draw the same pixels as the 1999 code.
ComparePrim 1, 100, 100, 400, 170
ComparePrim 1, 10, 19, 100, 24
ComparePrim 1, 0, 0, 639, 479
ComparePrim 1, 211, 77, 530, 391
ComparePrim 2, 100, 100, 400, 118
ComparePrim 2, 0, 0, 639, 18
ComparePrim 3, 100, 100, 112, 112
ComparePrim 3, 300, 200, 312, 212

'1b. Text: every character, drawn by cout, equals what QBasic prints.
GlyphCase 9
GlyphCase 2

'2. A full repaint equals the back-to-front reference, for each scene.
FOR sc = 1 TO 3
        Scene sc
        gFill 0, 0, 639, 479, 8
        RepaintRect 0, 0, 639, 479
        CompareToLegacy "full repaint, scene" + STR$(sc)
NEXT

'2b. Strips one pixel thick: VIEW SCREEN cannot clip them directly. Paint the
'scene, corrupt the strip, repaint the strip, and expect the reference image.
Scene 2
RepaintRect 0, 0, 639, 479
ThinCase "row strip across windows", 117, 191, 367, 191
ThinCase "column strip across windows", 250, 100, 250, 300
ThinCase "single pixel inside a window", 260, 160, 260, 160
ThinCase "column at the right screen edge", 639, 0, 639, 479
ThinCase "row at the bottom screen edge", 0, 479, 639, 479
ThinCase "pixel in the bottom right corner", 639, 479, 639, 479
ThinCase "pixel in the top left corner", 0, 0, 0, 0
ThinCase "row at the top screen edge", 0, 0, 639, 0
ThinCase "row just above a covering window", 260, 149, 300, 149
ThinCase "column just left of a covering window", 249, 160, 249, 180
ThinCase "pixel just above a covering window", 280, 149, 280, 149

'3. Each incremental operation leaves the screen as a full repaint would.
Scene 2
RepaintRect 0, 0, 639, 479
FOR i = 1 TO 12
        WinMoveTo 2, WGData(2, 1) + 17, WGData(2, 2) + 11
        IF i MOD 4 = 0 THEN CompareToLegacy "drag window 2, step" + STR$(i)
NEXT
WinMoveTo 2, -60, -20
CompareToLegacy "move window 2 off the top left"
WinMoveTo 4, 600, 450
CompareToLegacy "move window 4 off the bottom right"
WinMoveTo 2, 150, 90
CompareToLegacy "move window 2 back"
WinSizeTo 1, 330, 260
CompareToLegacy "grow window 1"
WinSizeTo 1, 10, 5
CompareToLegacy "shrink window 1 below the minimum"
WinSizeTo 5, 400, 80
CompareToLegacy "widen window 5"
FOR w = 1 TO 6
        WinPutTop w
        CompareToLegacy "raise window" + STR$(w)
NEXT
WinSetState 2, 2
CompareToLegacy "maximise window 2"
WinSetState 2, 1
CompareToLegacy "restore window 2"
WinSetState 1, 0
CompareToLegacy "roll up window 1"
WinSetState 1, 1
CompareToLegacy "unroll window 1"
WinSetState 3, 1
CompareToLegacy "unroll window 3"

Scene 3
RepaintRect 0, 0, 639, 479
WinSetState 3, 1
CompareToLegacy "restore the maximised window"
WinMoveTo 3, 250, 150
CompareToLegacy "move it"
WinSetState 3, 2
CompareToLegacy "maximise it again"

END SUB
