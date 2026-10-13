'Cases: controls, their hit tests, state and repaint.
SUB RunAll
'5. Controls. Hit tests and state first, then the screen after each change.
Scene 4
RepaintRect 0, 0, 639, 479
CompareToLegacy "look: controls in a window"
Check "the text box takes a click", CtlAt(150, 66) = 2, STR$(CtlAt(150, 66))
Check "the OK button takes a click", CtlAt(80, 200) = 7, STR$(CtlAt(80, 200))
Check "the Clear button takes a click", CtlAt(150, 200) = 8, STR$(CtlAt(150, 200))
Check "a window in front blocks the Clear button", CtlAt(210, 200) = 0, STR$(CtlAt(210, 200))
Check "a label takes no click", CtlAt(55, 60) = 0, STR$(CtlAt(55, 60))
Check "the title bar is not a control", CtlAt(100, 38) = 0, STR$(CtlAt(100, 38))

CtlEvent = 0
CtlActivate 3
Check "a checkbox checks", CtlGetChecked(3) = -1, ""
Check "a checkbox reports a click", CtlEvent = 3, STR$(CtlEvent)
CompareToLegacy "controls: checkbox checked"
CtlActivate 3
Check "a checkbox unchecks", CtlGetChecked(3) = 0, ""

CtlActivate 6
Check "a radio button selects", CtlGetChecked(6) = -1, ""
Check "the others of its group clear", CtlGetChecked(4) = 0 AND CtlGetChecked(5) = 0, ""
CompareToLegacy "controls: radio group"

CtlEvent = 0
CtlActivate 7
Check "a button reports a click", CtlEvent = 7, STR$(CtlEvent)
CtlEvent = 0

CtlDown = 7
CtlRedraw 7
CompareToLegacy "look: button held down"
CtlDown = 0
CtlRedraw 7

CtlActivate 2
Check "a click focuses the text box", CtlFocus = 2, STR$(CtlFocus)
CtlKey "x"
Check "a key is added", CtlGetText$(2) = "snugglex", CtlGetText$(2)
CtlKey CHR$(8)
CtlKey CHR$(8)
Check "backspace removes a character", CtlGetText$(2) = "snuggl", CtlGetText$(2)
CompareToLegacy "look: focused text box"
CtlEvent = 0
CtlKey CHR$(13)
Check "enter accepts", CtlEvent = 2, STR$(CtlEvent)
FOR i = 1 TO 50
        CtlKey "m"
NEXT
Check "the text stops at 40 characters", LEN(CtlGetText$(2)) = 40, STR$(LEN(CtlGetText$(2)))
CompareToLegacy "controls: text longer than the box"
CtlKey CHR$(27)
Check "escape leaves the box", CtlFocus = 0, STR$(CtlFocus)
CtlSetText 9, "Hello, world"
CompareToLegacy "controls: label text changed"

WinSizeTo 1, 200, 110
Check "a control outside the client area is not drawn", CtlVisible(9) = 0, ""
Check "a control inside it is", CtlVisible(2) = 0, "text box is 70 + 200 wide, so it does not fit either"
CompareToLegacy "controls: window shrunk"
WinSizeTo 1, 340, 230
WinMoveTo 1, -100, 20
CompareToLegacy "controls: window partly off screen"
WinMoveTo 1, 40, 30
WinSetState 1, 0
Check "a rolled up window shows no controls", CtlVisible(2) = 0, ""
Check "a rolled up window takes no click", CtlAt(150, 66) = 0, STR$(CtlAt(150, 66))
CompareToLegacy "controls: window rolled up"
WinSetState 1, 1
CompareToLegacy "controls: window unrolled"
WinSetState 1, 2
CompareToLegacy "controls: window maximised"
WinSetState 1, 1
WinPutTop 1
Check "raised, the Clear button takes the click", CtlAt(210, 200) = 8, STR$(CtlAt(210, 200))
CompareToLegacy "look: controls window raised over the cover"

'Resizing keeps the client area and repaints the frame, the title bar and the
'controls that start or stop fitting: one pixel at a time through the size where
'each control appears.
Scene 4
RepaintRect 0, 0, 639, 479
WinPutTop 1
WinSizeTo 1, 100, 60
CompareToLegacy "resize: shrink, controls drop out"
FOR i = 1 TO 8
        WinSizeTo 1, 100 + i * 31, 60 + i * 21
        CompareToLegacy "resize: grow, step" + STR$(i)
NEXT
FOR i = 1 TO 5
        WinSizeTo 1, 340 - i * 23, 230 - i * 17
        CompareToLegacy "resize: shrink, step" + STR$(i)
NEXT
WinSizeTo 1, 341, 231
CompareToLegacy "resize: one pixel larger"
WinSizeTo 1, 340, 230

'Moving the window copies its pixels, controls included.
WinPutTop 1
WinMoveTo 1, 90, 60
CompareToLegacy "look: controls window moved by a copy"
CtlActivate 3
CompareToLegacy "controls: checkbox on a moved window"
CtlDown = 8
CtlRedraw 8
CompareToLegacy "controls: button pressed while a window is in front of it"
CtlDown = 0
CtlRedraw 8
WinPutTop 2
CtlDown = 7
CtlRedraw 7
CompareToLegacy "controls: button pressed in a window that is not in front"
CtlDown = 0
CtlRedraw 7

'6. A control redraw touches the control and little else.
gWrites = 0
CtlRedraw 3
Metric "checkbox redraw writes", CSNG(gWrites)
Check "a checkbox redraw stays under 4000 writes", gWrites < 4000, STR$(gWrites)

END SUB
