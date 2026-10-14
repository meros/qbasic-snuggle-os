'Cases: the real main loop (MainStep) with a scripted mouse and keys: clicks on
'icons, title bar buttons, borders, controls, immediate mode buttons, and keys.
SUB RunAll
NoSync = -1
WinReset
IconCount = 0
AppStartAll
RepaintRect 0, 0, 639, 479
hello = WOrder(1)
Check "input: the desktop starts one Hello window and a dock of three icons", WNumber = 1 AND HGet(hello, WfApp) = AppIdHello AND IconCount = 3, STR$(WNumber) + STR$(IconCount)
CompareToLegacy "input: the desktop at start"

'An icon starts an instance; windows cascade.
ClickIcon AppIdCalc
calc = WOrder(1)
Check "input: the Calc icon starts Calc in front", WNumber = 2 AND HGet(calc, WfApp) = AppIdCalc, STR$(WNumber)
CompareToLegacy "input: calc launched by its icon"
ClickIcon AppIdCalc
Check "input: a second click starts a second instance", WNumber = 3, STR$(WNumber)
extra = WOrder(1)
WinClose extra
Click 600, 300
Check "input: a click on the empty desktop does nothing", WNumber = 2, STR$(WNumber)

'A click on a window behind raises it.
WinRect hello, hx1, hy1, hx2, hy2
Click hx2 - 60, hy1 + 8
Check "input: a click on the title of a window behind raises it", WOrder(1) = hello, STR$(WOrder(1))
CompareToLegacy "input: hello raised"
WinPutTop calc

'Dragging the title bar moves the window by the pointer's movement.
WinRect calc, cx1, cy1, cx2, cy2
DragTo cx1 + 40, cy1 + 8, cx1 + 70, cy1 + 33
Check "input: dragging the title bar moves the window", HGet(calc, WfX) = cx1 + 30 AND HGet(calc, WfY) = cy1 + 25, STR$(HGet(calc, WfX) - cx1) + STR$(HGet(calc, WfY) - cy1)
CompareToLegacy "input: calc dragged"

'Dragging the corner resizes it.
WinRect calc, cx1, cy1, cx2, cy2
w0 = HGet(calc, WfW)
h0 = HGet(calc, WfH)
DragTo cx2 - 1, cy2 - 1, cx2 + 29, cy2 + 14
Check "input: dragging the corner resizes the window", HGet(calc, WfW) = w0 + 30 AND HGet(calc, WfH) = h0 + 15, STR$(HGet(calc, WfW) - w0) + STR$(HGet(calc, WfH) - h0)
CompareToLegacy "input: calc resized"
WinSizeTo calc, w0, h0

'The title bar buttons: roll up, maximise, restore.
TitleButton calc, 3
Check "input: the roll up button rolls the window up", HGet(calc, WfState) = 0, STR$(HGet(calc, WfState))
CompareToLegacy "input: rolled up by a click"
TitleButton calc, 3
Check "input: and unrolls it", HGet(calc, WfState) = 1, ""
TitleButton calc, 2
Check "input: the maximise button maximises", HGet(calc, WfState) = 2, ""
CompareToLegacy "input: maximised by a click"
TitleButton calc, 2
Check "input: and restores", HGet(calc, WfState) = 1, ""
CompareToLegacy "input: restored by a click"

'Immediate mode keys of the calculator, by their place on the screen.
CalcClick calc, "1"
CalcClick calc, "2"
CalcClick calc, "+"
CalcClick calc, "7"
CalcClick calc, "="
Check "input: 12 + 7 = 19 with clicks on the keys", CtlGetText$(AppGet(calc, CalcDisp)) = "19", CtlGetText$(AppGet(calc, CalcDisp))
CompareToLegacy "input: the calculator after clicks"
'Press on a key, let go away from it: nothing happens.
WinRect calc, cx1, cy1, cx2, cy2
kx = cx1 + 3 + 8 + 5
ky = cy1 + TtlHeight + 4 + 32 + 5
MsClear
MsAdd kx, ky, 1
MsAdd kx, ky, 1
MsAdd kx + 150, ky + 150, 0
MainStep
MsClear
Check "input: a key let go away from it is not pressed", CtlGetText$(AppGet(calc, CalcDisp)) = "19", CtlGetText$(AppGet(calc, CalcDisp))

'Controls of Hello: a retained button, the text box and keys.
WinPutTop hello
tb = AppGet(hello, HelloWho)
CtlRect tb, tx1, ty1, tx2, ty2
Click tx1 + 20, ty1 + 8
Check "input: a click on the text box focuses it", CtlFocus = tb, STR$(CtlFocus)
Typ "ab" + CHR$(8) + "c"
Check "input: keys go to the focused text box", CtlGetText$(tb) = "snuggleac", CtlGetText$(tb)
ok = AppGet(hello, HelloOk)
CtlRect ok, ox1, oy1, ox2, oy2
Click ox1 + 10, oy1 + 8
Check "input: a click on OK greets the name", CtlGetText$(AppGet(hello, HelloMsg)) = "Hello, snuggleac", CtlGetText$(AppGet(hello, HelloMsg))
CompareToLegacy "input: hello after OK"

'Notepad: keys, arrows, save, load.
ClickIcon AppIdNotepad
np = WOrder(1)
Check "input: the Notepad icon starts Notepad", HGet(np, WfApp) = AppIdNotepad, ""
Typ "hi" + CHR$(13) + "xq"
Check "input: Notepad takes keys, q included", BlockText$(AppGet(np, NpLine)) = "hi" AND BlockText$(AppGet(np, NpLine + 1)) = "xq" AND QuitFlag = 0, BlockText$(AppGet(np, NpLine + 1))
Typ CHR$(0) + "H"
Check "input: the up arrow moves to the line above", AppGet(np, NpCur) = 0, STR$(AppGet(np, NpCur))
CompareToLegacy "input: notepad with text"
NotepadButton np, 1
Check "input: Save says so", BlockText$(AppGet(np, NpMsg)) = "Saved NOTE.TXT", BlockText$(AppGet(np, NpMsg))
BlockSetText AppGet(np, NpLine), "changed"
BlockSetText AppGet(np, NpLine + 1), ""
NotepadButton np, 2
Check "input: Load brings the saved lines back", BlockText$(AppGet(np, NpLine)) = "hi" AND BlockText$(AppGet(np, NpLine + 1)) = "xq", BlockText$(AppGet(np, NpLine))
KILL "NOTE.TXT"
NotepadButton np, 2
Check "input: Load without a file says so", BlockText$(AppGet(np, NpMsg)) = "No NOTE.TXT", BlockText$(AppGet(np, NpMsg))

'The dock enlarged under the pointer, over the windows (a picture of the desktop).
ClickIcon AppIdCalc
WinMoveTo WOrder(1), 330, 200
MsClear
MsAdd DockCx(2) + 6, 455, 0
MainStep
Check "input: the pointer over the dock enlarges the icon under it", DockSize(2) > DockBase + 20, STR$(DockSize(2))
CompareToLegacy "look: the desktop with windows and the dock enlarged"
MsClear
MsAdd 600, 100, 0
MainStep

'The close button frees what the window owned; Q quits when no app takes keys.
used = HeapTop
TitleButton np, 1
Check "input: the close button closes Notepad and frees its blocks", HeapTop < used AND HKind(np) = 0, STR$(used) + STR$(HeapTop)
WinPutTop calc
Typ "q"
Check "input: Q quits the main loop when the front app takes no keys", QuitFlag = -1, STR$(QuitFlag)
QuitFlag = 0
NoSync = 0
WinReset
IconCount = 0
END SUB

'The dock icon of an app, clicked.
SUB ClickIcon (app)
FOR i = 1 TO IconCount
        IF IconApp(i) = app THEN Click DockCx(i), 460
NEXT
END SUB

'Click the title bar button b of a window: 1 close, 2 maximise, 3 roll up.
SUB TitleButton (who, b)
WinRect who, x1, y1, x2, y2
Click x2 - TtlHeight * b + 5, y1 + 8
END SUB

'Click the calculator key k$ (found by its place in the grid).
SUB CalcClick (w, k$)
keys$ = "789/456*123-0.=+"
i = INSTR(keys$, k$) - 1
WinRect w, x1, y1, x2, y2
Click x1 + 3 + 8 + (i MOD 4) * 44 + 5, y1 + TtlHeight + 4 + 32 + (i \ 4) * 34 + 5
END SUB

'Click Notepad's button 1 (Save) or 2 (Load).
SUB NotepadButton (w, b)
WinRect w, x1, y1, x2, y2
Click x1 + 3 + 8 + (b - 1) * 68 + 5, y1 + TtlHeight + 4 + 192 + 5
END SUB

'A drag: down at the first point, five moves to the second, up there.
SUB DragTo (x1, y1, x2, y2)
MsClear
MsAdd x1, y1, 1
FOR i = 1 TO 4
        MsAdd x1 + (x2 - x1) * i \ 4, y1 + (y2 - y1) * i \ 4, 1
NEXT
MsAdd x2, y2, 0
MainStep
MsClear
END SUB

'Keys one pass at a time.
SUB Typ (k$)
KeyBuf$ = k$
DO WHILE LEN(KeyBuf$) > 0
        MsClear
        MainStep
LOOP
END SUB
