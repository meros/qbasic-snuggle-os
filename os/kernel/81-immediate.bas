'Part immediate: controls an app declares each time it paints.

'@if immediate
'---------------------------------------------------------------------------
'Immediate mode controls. A button or label of an app that has a paint
'procedure (manifest paint=) is not stored anywhere: the app declares it each
'time its window is painted, with UiButton and UiLabel, and the kernel runs the
'same procedure to find a click. So they cost no heap and no handles, and their
'state is whatever the app keeps in its data block. A button id is a number the
'app chooses, 1 or more and unique in the procedure (0 means no button).
'  mode 0 draws, mode 1 finds the button under the pointer, mode 2 returns -1
'  for the button that was clicked, and the app does the work in its IF. Mode 3
'  is the layout pass before the retained controls are drawn: nothing draws,
'  and the app places its controls from UiW and UiH (CtlPlace).
'---------------------------------------------------------------------------
'Run the app's paint procedure for a window in a mode.
SUB UiRun (who, md)
oldmode = UiMode
oldwin = UiWin
UiMode = md
UiWin = who
WinGeom who, x, y, w, h, state
UiOx = x + 3
UiOy = y + TtlHeight + 4
UiRight = x + w - 3
UiBottom = y + h - 3
AppPaint HGet(who, WfApp), who
UiMode = oldmode
UiWin = oldwin
END SUB

'A push button at x, y (relative to the client area). In mode 2 it returns -1
'when it is the clicked one. A button that does not fit in the client area is
'neither drawn nor hit, as for retained controls.
'@api Immediate mode | A push button (`id` 1 or more, x and y relative to the client area). Returns -1 when it was clicked (only in the click pass), so the app does its work in the IF.
FUNCTION UiButton (id, x, y, w, h, cap$)
UiButton = 0
IF id < 1 THEN EXIT FUNCTION
x1 = UiOx + x
y1 = UiOy + y
x2 = x1 + w - 1
y2 = y1 + h - 1
IF x1 < UiOx OR y1 < UiOy OR x2 > UiRight OR y2 > UiBottom THEN EXIT FUNCTION
SELECT CASE UiMode
CASE 0
        IF NOT Outside(x1, y1, x2, y2) THEN DrawPush x1, y1, x2, y2, cap$, (UiDown = id)
CASE 1
        IF UiMx >= x1 AND UiMx <= x2 AND UiMy >= y1 AND UiMy <= y2 THEN
                UiHitId = id
                UiHx1 = x1: UiHy1 = y1: UiHx2 = x2: UiHy2 = y2
        END IF
CASE 2
        IF id = UiClickId THEN UiButton = -1
END SELECT
END FUNCTION

'The size of the client area in pixels, for an app that paints all of it.
'@api Immediate mode | Width of the client area, in a paint procedure.
FUNCTION UiW
UiW = UiRight - UiOx + 1
END FUNCTION

'@api Immediate mode | -1 in the layout pass, the first call of the paint procedure when a window is drawn: place controls with `CtlPlace` and draw nothing.
FUNCTION UiLayout
UiLayout = (UiMode = 3)
END FUNCTION

'@api Immediate mode | Height of the client area, in a paint procedure.
FUNCTION UiH
UiH = UiBottom - UiOy + 1
END FUNCTION

'A filled rectangle in a colour, x and y relative to the client area. It is
'cut to the client area, so a game can let things slide in and out (drawing only).
'@api Immediate mode | A filled rectangle in colour `c`, relative to the client area and cut to it.
SUB UiFill (x, y, w, h, c)
IF UiMode <> 0 THEN EXIT SUB
x1 = UiOx + x
y1 = UiOy + y
x2 = x1 + w - 1
y2 = y1 + h - 1
IF x1 < UiOx THEN x1 = UiOx
IF y1 < UiOy THEN y1 = UiOy
IF x2 > UiRight THEN x2 = UiRight
IF y2 > UiBottom THEN y2 = UiBottom
IF x1 <= x2 AND y1 <= y2 THEN gFill x1, y1, x2, y2, c
END SUB

'Text in black on the client background (drawing only).
'@api Immediate mode | Text in black on the client area, `h` high.
SUB UiLabel (x, y, w, h, t$)
IF UiMode <> 0 THEN EXIT SUB
x1 = UiOx + x
y1 = UiOy + y
IF x1 < UiOx OR y1 < UiOy OR x1 + w - 1 > UiRight OR y1 + h - 1 > UiBottom THEN EXIT SUB
CtlCap t$, x1, y1 + (h - 16) \ 2 - 1, w, 15
END SUB

'Click a button by its id: the app's procedure runs in mode 2, then the client
'area is repainted, since the app may have changed what it shows.
SUB UiFire (who, id)
UiClickId = id
UiRun who, 2
UiClickId = 0
WinInvalidate who
END SUB

'A click at a screen point in a window. Returns -1 when an immediate button
'took it: it looks pressed while the pointer is on it, and counts when the
'button goes up on it.
FUNCTION UiClick (who, mx, my)
UiClick = 0
UiMx = mx
UiMy = my
UiHitId = 0
UiRun who, 1
IF UiHitId = 0 THEN EXIT FUNCTION
UiClick = -1
id = UiHitId
x1 = UiHx1: y1 = UiHy1: x2 = UiHx2: y2 = UiHy2
UiDown = id
Repaint x1, y1, x2, y2
isin = -1
DO
        mouse.getpos mx, my
        over = (mx >= x1 AND mx <= x2 AND my >= y1 AND my <= y2)
        IF over <> isin THEN
                isin = over
                IF isin THEN UiDown = id ELSE UiDown = 0
                Repaint x1, y1, x2, y2
        END IF
LOOP WHILE mouse.getbutton = LB
'where the pointer is now decides, not where it was at the last look
mouse.getpos mx, my
isin = (mx >= x1 AND mx <= x2 AND my >= y1 AND my <= y2)
UiDown = 0
IF isin THEN UiFire who, id ELSE Repaint x1, y1, x2, y2
END FUNCTION
'@else
SUB UiRun (who, md)
END SUB

FUNCTION UiLayout
UiLayout = 0
END FUNCTION

FUNCTION UiClick (who, mx, my)
UiClick = 0
END FUNCTION
'@endif
