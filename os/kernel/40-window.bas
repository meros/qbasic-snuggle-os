'Windows: making, closing, moving, sizing, the order, hit testing, dragging.

'@@HIT-BEGIN
'What is at a screen point in a window: 1 to 3 the title bar buttons (1 is the
'rightmost), 4 the title bar, 5 the right border, 6 the bottom border, 7 the
'corner, 8 the client area, 0 none. A rolled-up window has a title bar only.
FUNCTION WinPart (who, mx, my)
WinPart = 0
WinGeom who, x, y, w, h, state
IF mx < x OR mx > x + w OR my < y OR my > y + h THEN EXIT FUNCTION
FOR b = 1 TO 3
        bx = x + w - TtlHeight * b
        IF mx >= bx AND mx <= bx + TtlHeight - 6 AND my >= y + 3 AND my <= y + TtlHeight - 3 THEN
                WinPart = b
                EXIT FUNCTION
        END IF
NEXT
IF my <= y + TtlHeight THEN
        WinPart = 4
ELSEIF my >= y + h - 3 THEN
        IF mx >= x + w - 3 THEN WinPart = 7 ELSE WinPart = 6
ELSEIF mx >= x + w - 3 THEN
        WinPart = 5
ELSEIF state <> 0 THEN
        WinPart = 8
END IF
END FUNCTION
'@@HIT-END

SUB GetStats (who, text$, x, y, w, h, state)
text$ = HText(who)
WinGeom who, x, y, w, h, state
END SUB

SUB WinGeom (who, x, y, w, h, state)
b = HBase(who)
IF Heap(b + WfW) < 90 THEN Heap(b + WfW) = 90
IF Heap(b + WfH) < TtlHeight + 6 THEN Heap(b + WfH) = TtlHeight + 6
x = Heap(b + WfX)
y = Heap(b + WfY)
w = Heap(b + WfW)
h = Heap(b + WfH)
state = Heap(b + WfState)
IF state = 0 THEN h = TtlHeight
IF state = 2 THEN w = 640: h = 480: x = 0: y = 0
END SUB

'Make a window and put it in front. The window is WNew, 0 when the heap had no
'room.
SUB NewWin (text$, x, y, w, h)
WNew = MemAlloc(0, KWin, WinWords)
IF WNew = 0 THEN EXIT SUB
HOwner(WNew) = WNew
HText(WNew) = text$
HSet WNew, WfX, x
HSet WNew, WfY, y
HSet WNew, WfW, w
HSet WNew, WfH, h
HSet WNew, WfState, 1
WNumber = WNumber + 1
WOrder(WNumber) = WNew
WinMakeHighest WNew
END SUB

'Close a window: it leaves the order, everything it owns (its controls, its data)
'is freed and the heap compacted, and the area it covered is repainted. The
'argument is copied first, so it may be an element of WOrder.
'@api Windows | Close a window: its controls, blocks and timers go, and the area is repainted.
SUB WinClose (win)
who = win
WinRect who, x1, y1, x2, y2
FOR i = 1 TO WNumber
        IF WOrder(i) = who THEN p = i
NEXT
FOR i = p TO WNumber - 1
        WOrder(i) = WOrder(i + 1)
NEXT
WNumber = WNumber - 1
MemFreeAll who
TimersDrop who
IF HSize(CtlFocus) = 0 THEN CtlFocus = 0
IF HSize(CtlDown) = 0 THEN CtlDown = 0
Repaint x1, y1, x2, y2
END SUB

'Repaint the area of a window, for a window that was just made.
SUB WinShow (who)
WinRect who, x1, y1, x2, y2
Repaint x1, y1, x2, y2
END SUB

'All windows, controls and heap blocks gone.
SUB WinReset
WNumber = 0
FOR h = 1 TO HeapMax
        HSize(h) = 0
        HKind(h) = 0
        HText(h) = ""
NEXT
HeapTop = 0
CtlFocus = 0
CtlDown = 0
CtlEvent = 0
END SUB

'@@DRAG-BEGIN
'Follow the pointer until the button goes up. what: 0 moves the window, 1 drags
'the right border, 2 the bottom border, 3 the corner.
SUB StartDrag (what, who)
mouse.getpos ox, oy
x = ox: y = oy
WinGeom who, wx, wy, ww, wh, wstate
DO
        lx = x: ly = y
        mouse.getpos x, y
        IF lx <> x OR ly <> y THEN
                IF what = 0 THEN
                        WinMoveTo who, wx + (x - ox), wy + (y - oy)
                ELSE
                        nw = ww: nh = wh
                        IF what <> 2 THEN nw = ww + (x - ox)
                        IF what <> 1 THEN nh = wh + (y - oy)
                        WinSizeTo who, nw, nh
                END IF
        END IF
LOOP UNTIL mouse.getbutton <> LB
END SUB

'@@DRAG-END

SUB WinMakeHighest (num)

FOR a = 1 TO WNumber
IF WOrder(a) = num THEN
where = a
END IF
NEXT


FOR a = where - 1 TO 1 STEP -1
WOrder(a + 1) = WOrder(a)
NEXT
WOrder(1) = num
END SUB

'@api Windows | Bring a window to the front.
SUB WinPutTop (who)
IF WOrder(1) <> who THEN
        IF CtlFocus > 0 THEN
                IF HOwner(CtlFocus) <> who THEN CtlSetFocus 0
        END IF
        WinMakeHighest who
        WinRect who, x1, y1, x2, y2
        RepaintChange x1, y1, x2, y2, x1, y1, x2, y2
END IF
END SUB

'The rectangle a window covers, both ends included (screen coordinates).
'@api Windows | The screen rectangle of a window, both ends included.
SUB WinRect (who, x1, y1, x2, y2)
WinGeom who, x1, y1, x2, y2, state
x2 = x1 + x2
y2 = y1 + y2
END SUB

'Move a window and paint only what changed.
'@api Windows | Move a window to x, y. Only what changed is repainted.
SUB WinMoveTo (who, nx, ny)
WinRect who, ox1, oy1, ox2, oy2
dx = nx - HGet(who, WfX)
dy = ny - HGet(who, WfY)
IF dx = 0 AND dy = 0 THEN EXIT SUB
HSet who, WfX, nx
HSet who, WfY, ny
WinRect who, nx1, ny1, nx2, ny2

'The window in front shows all of itself, so its pixels can be copied. Only the
'part that is on the screen before and after can be..
IF WOrder(1) = who AND ClipActive = 0 THEN
        sx1 = ox1: sx2 = ox2: sy1 = oy1: sy2 = oy2
        BlitSpan sx1, sx2, dx, 639
        BlitSpan sy1, sy2, dy, 479
        IF sx1 <= sx2 AND sy1 <= sy2 THEN
                mouse.hide
                WaitRetrace
                BlitMove sx1, sy1, sx2, sy2, dx, dy
                RepaintMinus ox1, oy1, ox2, oy2, sx1 + dx, sy1 + dy, sx2 + dx, sy2 + dy
                RepaintMinus nx1, ny1, nx2, ny2, sx1 + dx, sy1 + dy, sx2 + dx, sy2 + dy
                mouse.show
                EXIT SUB
        END IF
END IF
RepaintChange ox1, oy1, ox2, oy2, nx1, ny1, nx2, ny2
END SUB

'Cut the span a1 to a2 so that it and the span moved by d are both inside 0 to last.
SUB BlitSpan (a1, a2, d, last)
IF a1 < 0 THEN a1 = 0
IF a1 + d < 0 THEN a1 = -d
IF a2 > last THEN a2 = last
IF a2 + d > last THEN a2 = last - d
END SUB

'Resize a window and paint only what changed.
'@api Windows | Resize a window. Only what changed is repainted.
SUB WinSizeTo (who, nw, nh)
WinRect who, ox1, oy1, ox2, oy2
oldst = HGet(who, WfState)
FOR i = 1 TO HeapMax
        IF HKind(i) = KCtl AND HOwner(i) = who THEN VisOld(i) = CtlVisible(i)
NEXT
HSet who, WfW, nw
HSet who, WfH, nh
WinRect who, nx1, ny1, nx2, ny2
IF oldst <> 1 THEN
        RepaintChange ox1, oy1, ox2, oy2, nx1, ny1, nx2, ny2
        EXIT SUB
END IF

'A normal window keeps its top left corner. Repaint what left the window or
'joined it, the title bar (the buttons move and the title is cut to the width),
'and the frame bands. The client area keeps its pixels, except for controls that
'now fit or no longer fit.
mouse.hide
WaitRetrace
RepaintMinus ox1, oy1, ox2, oy2, nx1, ny1, nx2, ny2
RepaintMinus nx1, ny1, nx2, ny2, ox1, oy1, ox2, oy2
RepaintRect nx1, ny1, nx2, ny1 + TtlHeight
fy = ny1 + TtlHeight + 1
RepaintRect nx2 - 3, fy, nx2, ny2
RepaintRect nx1, ny2 - 3, nx2, ny2
IF ox2 < nx2 THEN RepaintRect ox2 - 3, fy, ox2, ny2
IF oy2 < ny2 THEN RepaintRect nx1, oy2 - 3, nx2, oy2
FOR i = 1 TO HeapMax
        IF HKind(i) = KCtl AND HOwner(i) = who THEN
                IF VisOld(i) <> CtlVisible(i) THEN
                        CtlRect i, cx1, cy1, cx2, cy2
                        RepaintRect cx1, cy1, cx2, cy2
                END IF
        END IF
NEXT
mouse.show
END SUB

'Set the window state (0 rolled up, 1 normal, 2 maximised) and paint only what changed.
'@api Windows | Set the state of a window: 0 rolled up, 1 normal, 2 maximised.
SUB WinSetState (who, st)
WinRect who, ox1, oy1, ox2, oy2
oldst = HGet(who, WfState)
HSet who, WfState, st
WinRect who, nx1, ny1, nx2, ny2
IF oldst <> 2 AND st <> 2 THEN
        'rolled up or normal before and after: same position and width, same
        'title bar. Only the part below it changes.
        IF oy2 > ny2 THEN ny2 = oy2
        Repaint nx1, ny1 + TtlHeight + 1, nx2, ny2
ELSE
        RepaintChange ox1, oy1, ox2, oy2, nx1, ny1, nx2, ny2
END IF
END SUB
