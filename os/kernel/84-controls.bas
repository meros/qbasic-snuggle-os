'Part controls: retained controls (and widgets).

'@if controls
'---------------------------------------------------------------------------
'Controls. A control belongs to a window and is drawn in its client area, after
'the frame, so it is repainted (and clipped) with the window. A control that
'does not fit inside the client area is not drawn and cannot be hit.
'Events are not callbacks: a click or an accepted text box sets CtlEvent to the
'control number, and the main loop reads it.
'---------------------------------------------------------------------------

'Add a control to a window and return its number. 0 when the heap is full
'(OomFlag), or when the window is 0, a window that could not be made.
'x, y, w, h are relative to the top left of the client area.
'@api Controls | Add a retained control (CtlLabel, CtlButton, CtlCheck, CtlRadio or CtlText) to a window. Returns its number, 0 when the heap is full.
FUNCTION CtlAdd (win, kind, x, y, w, h, cap$)
CtlAdd = 0
IF win < 1 THEN EXIT FUNCTION
id = MemAlloc(win, KCtl, CtlWords)
IF id = 0 THEN EXIT FUNCTION
HSet id, CfKind, kind
HSet id, CfX, x
HSet id, CfY, y
HSet id, CfW, w
HSet id, CfH, h
HSet id, CfGrp, 1
HText(id) = cap$
CtlAdd = id
END FUNCTION

'Move and size a control (x, y, w, h relative to the client area). An app calls
'it in its paint procedure when UiLayout is -1, to follow the window size.
'@api Controls | Move and size a control. Call it in the paint procedure when `UiLayout` is -1 (the layout pass, before the controls are drawn).
SUB CtlPlace (id, x, y, w, h)
IF id < 1 THEN EXIT SUB
HSet id, CfX, x
HSet id, CfY, y
HSet id, CfW, w
HSet id, CfH, h
END SUB

'The screen rectangle of a control, both ends included.
SUB CtlRect (id, x1, y1, x2, y2)
WinGeom HOwner(id), wx, wy, ww, wh, wstate
b = HBase(id)
x1 = wx + 3 + Heap(b + CfX)
y1 = wy + TtlHeight + 4 + Heap(b + CfY)
x2 = x1 + Heap(b + CfW) - 1
y2 = y1 + Heap(b + CfH) - 1
END SUB

'-1 when the control is drawn: its window is not rolled up and the whole
'control is inside the client area.
FUNCTION CtlVisible (id)
CtlVisible = 0
WinGeom HOwner(id), x, y, w, h, state
IF state = 0 THEN EXIT FUNCTION
CtlRect id, x1, y1, x2, y2
IF x1 >= x + 3 AND y1 >= y + TtlHeight + 4 AND x2 <= x + w - 3 AND y2 <= y + h - 3 THEN CtlVisible = -1
END FUNCTION

SUB CtlDraw (id)
CtlRect id, x1, y1, x2, y2
w = HGet(id, CfW)
h = HGet(id, CfH)
cap$ = HText(id)
ty = y1 + (h - 16) \ 2 - 1
SELECT CASE HGet(id, CfKind)
CASE CtlLabel
        CtlCap cap$, x1, ty, w, 15
'@if widgets
CASE CtlButton
        DrawPush x1, y1, x2, y2, cap$, (CtlDown = id)
CASE CtlCheck
        bx = y1 + (h - 13) \ 2
        gBox x1, bx, x1 + 12, bx + 12, 1
        gFill x1 + 1, bx + 1, x1 + 11, bx + 11, 15
        IF HGet(id, CfChk) THEN
                gLine x1 + 3, bx + 3, x1 + 9, bx + 9, 0
                gLine x1 + 3, bx + 4, x1 + 8, bx + 9, 0
                gLine x1 + 9, bx + 3, x1 + 3, bx + 9, 0
                gLine x1 + 9, bx + 4, x1 + 4, bx + 9, 0
        END IF
        CtlCap cap$, x1 + 20, ty, w - 20, 15
CASE CtlRadio
        cx = x1 + 6
        cy = y1 + h \ 2
        gFill cx - 6, cy - 6, cx + 6, cy + 6, 15
        gCircle cx, cy, 6, 1
        IF HGet(id, CfChk) THEN gFill cx - 2, cy - 2, cx + 2, cy + 2, 0
        CtlCap cap$, x1 + 20, ty, w - 20, 15
'@endif
CASE CtlText
        IF CtlFocus = id THEN bc = 7 ELSE bc = 1
        gBox x1, y1, x2, y2, bc
        gFill x1 + 1, y1 + 1, x2 - 1, y2 - 1, 15
        n = (w - 8) \ 8
        shown$ = cap$
        IF LEN(shown$) > n THEN shown$ = RIGHT$(shown$, n)
        CtlCap shown$, x1 + 4, ty, w - 8, 15
        IF CtlFocus = id THEN
                cx = x1 + 4 + LEN(shown$) * 8
                gLine cx, y1 + 3, cx, y2 - 3, 0
        END IF
END SELECT
END SUB

'Draw the controls of one window, in the order they were added. A control
'outside the clip, or not entirely inside the client area, is not drawn.
SUB CtlDrawAll (who)
WinGeom who, x, y, w, h, state
IF state = 0 THEN EXIT SUB
UiRun who, 3
ox = x + 3
oy = y + TtlHeight + 4
FOR i = 1 TO HeapMax
        IF HKind(i) = KCtl AND HOwner(i) = who THEN
                x1 = ox + HGet(i, CfX)
                y1 = oy + HGet(i, CfY)
                x2 = x1 + HGet(i, CfW) - 1
                y2 = y1 + HGet(i, CfH) - 1
                IF x1 >= ox AND y1 >= oy AND x2 <= x + w - 3 AND y2 <= y + h - 3 THEN
                        IF NOT Outside(x1, y1, x2, y2) THEN CtlDraw i
                END IF
        END IF
NEXT
END SUB

'Repaint one control (and whatever covers part of it) after its state changed.
SUB CtlRedraw (id)
IF id < 1 OR id > HeapMax THEN EXIT SUB
IF HKind(id) <> KCtl THEN EXIT SUB
IF NOT CtlVisible(id) THEN EXIT SUB
CtlRect id, x1, y1, x2, y2
'Is a window in front of this one over the control?
covered = 0
FOR Cyc = 1 TO WNumber
        CW = WOrder(Cyc)
        IF CW = HOwner(id) THEN EXIT FOR
        WinRect CW, wx1, wy1, wx2, wy2
        IF NOT (wx2 < x1 OR wx1 > x2 OR wy2 < y1 OR wy1 > y2) THEN
                covered = -1
                EXIT FOR
        END IF
NEXT
IF covered THEN
        RepaintOwn HOwner(id), x1, y1, x2, y2
ELSE
        'Nothing in front: the client background, then the controls of this
        'window that touch the rectangle, in the order they were added.
        'only the part on the screen: VIEW SCREEN refuses the rest
        IF x1 < 0 THEN x1 = 0
        IF y1 < 0 THEN y1 = 0
        IF x2 > 639 THEN x2 = 639
        IF y2 > 479 THEN y2 = 479
        IF x1 > x2 OR y1 > y2 THEN EXIT SUB
        mouse.hide
        WaitRetrace
        ClipOn x1, y1, x2, y2
        gFill x1, y1, x2, y2, 15
        FOR i = 1 TO HeapMax
                IF HKind(i) = KCtl AND HOwner(i) = HOwner(id) THEN
                        CtlRect i, ax1, ay1, ax2, ay2
                        IF NOT (ax2 < x1 OR ax1 > x2 OR ay2 < y1 OR ay1 > y2) THEN
                                IF CtlVisible(i) THEN CtlDraw i
                        END IF
                END IF
        NEXT
        ClipOff
        mouse.show
END IF
END SUB

'The control that takes a click at a screen point in this window, 0 for none.
'Labels do not take clicks. Later controls are on top of earlier ones.
FUNCTION CtlHit (who, mx, my)
CtlHit = 0
FOR i = HeapMax TO 1 STEP -1
        IF HKind(i) = KCtl AND HOwner(i) = who AND HGet(i, CfKind) <> CtlLabel THEN
                IF CtlVisible(i) THEN
                        CtlRect i, x1, y1, x2, y2
                        IF mx >= x1 AND mx <= x2 AND my >= y1 AND my <= y2 THEN
                                CtlHit = i
                                EXIT FUNCTION
                        END IF
                END IF
        END IF
NEXT
END FUNCTION

'The control under a screen point, looking through the windows front to back.
'A window covers the controls of the windows behind it.
FUNCTION CtlAt (mx, my)
CtlAt = 0
FOR Cyc = 1 TO WNumber
        CW = WOrder(Cyc)
        WinRect CW, x1, y1, x2, y2
        IF mx >= x1 AND mx <= x2 AND my >= y1 AND my <= y2 THEN
                CtlAt = CtlHit(CW, mx, my)
                EXIT FUNCTION
        END IF
NEXT
END FUNCTION

'Give the keys to a text box, or to nobody (0).
'@api Controls | Give the keys to a text box, 0 for none.
SUB CtlSetFocus (id)
old = CtlFocus
IF old = id THEN EXIT SUB
CtlFocus = id
IF old > 0 THEN CtlRedraw old
IF id > 0 THEN CtlRedraw id
END SUB

'@if widgets
'Select one radio button of its group.
'@api Controls | Select a radio button and clear the others of its group.
SUB CtlSelect (id)
FOR i = 1 TO HeapMax
        IF i <> id AND HKind(i) = KCtl AND HGet(i, CfKind) = CtlRadio AND HOwner(i) = HOwner(id) AND HGet(i, CfGrp) = HGet(id, CfGrp) THEN
                IF HGet(i, CfChk) <> 0 THEN
                        HSet i, CfChk, 0
                        CtlRedraw i
                END IF
        END IF
NEXT
IF HGet(id, CfChk) = 0 THEN
        HSet id, CfChk, 1
        CtlRedraw id
END IF
END SUB
'@else
SUB CtlSelect (id)
END SUB
'@endif

'What a click on a control does, after the button went up on it.
SUB CtlActivate (id)
SELECT CASE HGet(id, CfKind)
'@if widgets
CASE CtlButton
        CtlEvent = id
CASE CtlCheck
        IF HGet(id, CfChk) THEN HSet id, CfChk, 0 ELSE HSet id, CfChk, 1
        CtlRedraw id
        CtlEvent = id
CASE CtlRadio
        CtlSelect id
        CtlEvent = id
'@endif
CASE CtlText
        CtlSetFocus id
END SELECT
END SUB

'Follow the mouse until the button goes up. A button looks pressed while the
'pointer is on it; the click counts when the button goes up on it.
SUB CtlTrack (id)
'@if widgets
IF HGet(id, CfKind) = CtlButton THEN
        CtlDown = id
        CtlRedraw id
        isin = -1
        CtlRect id, x1, y1, x2, y2
        DO
                mouse.getpos mx, my
                over = (mx >= x1 AND mx <= x2 AND my >= y1 AND my <= y2)
                IF over <> isin THEN
                        isin = over
                        IF isin THEN CtlDown = id ELSE CtlDown = 0
                        CtlRedraw id
                END IF
        LOOP WHILE mouse.getbutton = LB
        mouse.getpos mx, my
        isin = (mx >= x1 AND mx <= x2 AND my >= y1 AND my <= y2)
        CtlDown = 0
        CtlRedraw id
        IF isin THEN CtlActivate id
ELSE
'@endif
        DO: LOOP WHILE mouse.getbutton = LB
        CtlActivate id
'@if widgets
END IF
'@endif
END SUB

'A key for the focused text box. Printable keys are added (40 characters at
'most), Backspace removes one, Enter accepts (CtlEvent), Esc leaves the box.
SUB CtlKey (k$)
id = CtlFocus
IF id = 0 OR LEN(k$) <> 1 THEN EXIT SUB
IF HGet(id, CfKind) <> CtlText THEN EXIT SUB
c = ASC(k$)
cur$ = HText(id)
SELECT CASE c
CASE 8
        IF LEN(cur$) > 0 THEN
                HText(id) = LEFT$(cur$, LEN(cur$) - 1)
                CtlRedraw id
        END IF
CASE 13
        CtlEvent = id
CASE 27
        CtlSetFocus 0
CASE IS >= 32
        IF LEN(cur$) < 40 THEN
                HText(id) = cur$ + k$
                CtlRedraw id
        END IF
END SELECT
END SUB

'@api Controls | Set the text of a control and repaint it.
SUB CtlSetText (id, t$)
HText(id) = t$
CtlRedraw id
END SUB

'@api Controls | The text of a control (the text box content, a caption).
FUNCTION CtlGetText$ (id)
CtlGetText$ = HText(id)
END FUNCTION

'@if widgets
'Check or uncheck a checkbox or radio button. Use CtlSelect for a radio button
'that must exclude the others of its group.
'@api Controls | Check or uncheck a check box or radio button.
SUB CtlSetChecked (id, v)
IF v <> 0 THEN HSet id, CfChk, 1 ELSE HSet id, CfChk, 0
CtlRedraw id
END SUB

'@api Controls | -1 when a check box or radio button is checked.
FUNCTION CtlGetChecked (id)
IF HGet(id, CfChk) <> 0 THEN CtlGetChecked = -1 ELSE CtlGetChecked = 0
END FUNCTION
'@endif
'@else
SUB CtlDrawAll (who)
END SUB

SUB CtlPlace (id, x, y, w, h)
END SUB

FUNCTION CtlVisible (id)
CtlVisible = 0
END FUNCTION

SUB CtlRect (id, x1, y1, x2, y2)
x1 = 0: y1 = 0: x2 = -1: y2 = -1
END SUB

FUNCTION CtlHit (who, mx, my)
CtlHit = 0
END FUNCTION

SUB CtlTrack (id)
END SUB

SUB CtlKey (k$)
END SUB

SUB CtlSetFocus (id)
END SUB
'@endif
