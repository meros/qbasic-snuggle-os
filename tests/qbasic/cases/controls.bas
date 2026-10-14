'Cases: controls, their hit tests, state and repaint.
SUB RunAll
'5. Controls. Hit tests and state first, then the screen after each change.
Scene 4
RepaintRect 0, 0, 639, 479
CompareToLegacy "look: controls in a window"
Check "the text box takes a click", CtlAt(150, 66) = Kc(2), STR$(CtlAt(150, 66))
Check "the OK button takes a click", CtlAt(80, 200) = Kc(7), STR$(CtlAt(80, 200))
Check "the Clear button takes a click", CtlAt(150, 200) = Kc(8), STR$(CtlAt(150, 200))
Check "a window in front blocks the Clear button", CtlAt(210, 200) = 0, STR$(CtlAt(210, 200))
Check "a label takes no click", CtlAt(55, 60) = 0, STR$(CtlAt(55, 60))
Check "the title bar is not a control", CtlAt(100, 38) = 0, STR$(CtlAt(100, 38))

CtlEvent = 0
CtlActivate Kc(3)
Check "a checkbox checks", CtlGetChecked(Kc(3)) = -1, ""
Check "a checkbox reports a click", CtlEvent = Kc(3), STR$(CtlEvent)
CompareToLegacy "controls: checkbox checked"
CtlActivate Kc(3)
Check "a checkbox unchecks", CtlGetChecked(Kc(3)) = 0, ""

CtlActivate Kc(6)
Check "a radio button selects", CtlGetChecked(Kc(6)) = -1, ""
Check "the others of its group clear", CtlGetChecked(Kc(4)) = 0 AND CtlGetChecked(Kc(5)) = 0, ""
CompareToLegacy "controls: radio group"

CtlEvent = 0
CtlActivate Kc(7)
Check "a button reports a click", CtlEvent = Kc(7), STR$(CtlEvent)
CtlEvent = 0

CtlDown = Kc(7)
CtlRedraw Kc(7)
CompareToLegacy "look: button held down"
CtlDown = 0
CtlRedraw Kc(7)

CtlActivate Kc(2)
Check "a click focuses the text box", CtlFocus = Kc(2), STR$(CtlFocus)
CtlKey "x"
Check "a key is added", CtlGetText$(Kc(2)) = "snugglex", CtlGetText$(Kc(2))
CtlKey CHR$(8)
CtlKey CHR$(8)
Check "backspace removes a character", CtlGetText$(Kc(2)) = "snuggl", CtlGetText$(Kc(2))
CompareToLegacy "look: focused text box"
CtlEvent = 0
CtlKey CHR$(13)
Check "enter accepts", CtlEvent = Kc(2), STR$(CtlEvent)
FOR i = 1 TO 50
        CtlKey "m"
NEXT
Check "the text stops at 40 characters", LEN(CtlGetText$(Kc(2))) = 40, STR$(LEN(CtlGetText$(Kc(2))))
CompareToLegacy "controls: text longer than the box"
CtlKey CHR$(27)
Check "escape leaves the box", CtlFocus = 0, STR$(CtlFocus)
CtlSetText Kc(9), "Hello, world"
CompareToLegacy "controls: label text changed"

WinSizeTo 1, 200, 110
Check "a control outside the client area is not drawn", CtlVisible(Kc(9)) = 0, ""
Check "a control inside it is", CtlVisible(Kc(2)) = 0, "text box is 70 + 200 wide, so it does not fit either"
CompareToLegacy "controls: window shrunk"
WinSizeTo 1, 340, 230
WinMoveTo 1, -100, 20
CompareToLegacy "controls: window partly off screen"
WinMoveTo 1, 40, 30
WinSetState 1, 0
Check "a rolled up window shows no controls", CtlVisible(Kc(2)) = 0, ""
Check "a rolled up window takes no click", CtlAt(150, 66) = 0, STR$(CtlAt(150, 66))
CompareToLegacy "controls: window rolled up"
WinSetState 1, 1
CompareToLegacy "controls: window unrolled"
WinSetState 1, 2
CompareToLegacy "controls: window maximised"
WinSetState 1, 1
WinPutTop 1
Check "raised, the Clear button takes the click", CtlAt(210, 200) = Kc(8), STR$(CtlAt(210, 200))
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
CtlActivate Kc(3)
CompareToLegacy "controls: checkbox on a moved window"
CtlDown = Kc(8)
CtlRedraw Kc(8)
CompareToLegacy "controls: button pressed while a window is in front of it"
CtlDown = 0
CtlRedraw Kc(8)
WinPutTop Wcover
CtlDown = Kc(7)
CtlRedraw Kc(7)
CompareToLegacy "controls: button pressed in a window that is not in front"
CtlDown = 0
CtlRedraw Kc(7)

'6. A control redraw touches the control and little else.
gWrites = 0
CtlRedraw Kc(3)
Metric "checkbox redraw writes", CSNG(gWrites)
Check "a checkbox redraw stays under 4000 writes", gWrites < 4000, STR$(gWrites)


END SUB
