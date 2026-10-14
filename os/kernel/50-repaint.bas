'Repainting: the free rectangle list, clipping, copying, the retrace wait.

'Repaint a screen rectangle with the pointer hidden, after the retrace.
SUB Repaint (x1, y1, x2, y2)
mouse.hide
WaitRetrace
RepaintRect x1, y1, x2, y2
mouse.show
END SUB

'The same for a rectangle of one window (see RepaintWin).
SUB RepaintOwn (who, x1, y1, x2, y2)
mouse.hide
WaitRetrace
RepaintWin who, x1, y1, x2, y2
mouse.show
END SUB

SUB refresh
Repaint 0, 0, 639, 479
END SUB

'Paint the area the old rectangle covered, then the part of the new rectangle
'outside it. Every pixel is written once. The area they share is painted as part
'of the old rectangle.
SUB RepaintChange (ox1, oy1, ox2, oy2, nx1, ny1, nx2, ny2)
mouse.hide
WaitRetrace
RepaintRect ox1, oy1, ox2, oy2
RepaintMinus nx1, ny1, nx2, ny2, ox1, oy1, ox2, oy2
mouse.show
END SUB

'Paint a screen rectangle, both ends included, from the front window to the back.
'Each window is drawn through a clip (VIEW SCREEN) on the part of the rectangle
'that is still free, then that part is taken off the list. What is left at the
'end is background. No pixel is written twice, so nothing is erased and redrawn.
SUB RepaintRect (px1, py1, px2, py2)
PaintRects 0, px1, py1, px2, py2
END SUB

'Paint a rectangle of one window only: the parts of it that a window in front
'covers are left alone, and nothing else is repainted. For what an app changed in
'its own window, so a window over it is not erased and drawn again.
SUB RepaintWin (who, px1, py1, px2, py2)
PaintRects who, px1, py1, px2, py2
END SUB

'The work of both: only = 0 paints every window and the background, otherwise
'the windows in front of window only take their part off the list unpainted,
'only is painted, and the windows behind it and the background are not.
SUB PaintRects (only, px1, py1, px2, py2)
rx1 = px1: ry1 = py1: rx2 = px2: ry2 = py2
IF rx1 < 0 THEN rx1 = 0
IF ry1 < 0 THEN ry1 = 0
IF rx2 > 639 THEN rx2 = 639
IF ry2 > 479 THEN ry2 = 479
IF rx1 > rx2 OR ry1 > ry2 THEN EXIT SUB

n = 1
c = 0
RPut c, 1, rx1, ry1, rx2, ry2

FOR Cyc = 1 TO WNumber
        IF n = 0 THEN EXIT FOR
        CW = WOrder(Cyc)
        WinRect CW, wx1, wy1, wx2, wy2
        drawit = (only = 0 OR CW = only)
        m = 0
        d = 1 - c
        FOR i = 1 TO n
                fx1 = RL(c, i, 1): fy1 = RL(c, i, 2): fx2 = RL(c, i, 3): fy2 = RL(c, i, 4)
                ix1 = fx1: IF wx1 > ix1 THEN ix1 = wx1
                iy1 = fy1: IF wy1 > iy1 THEN iy1 = wy1
                ix2 = fx2: IF wx2 < ix2 THEN ix2 = wx2
                iy2 = fy2: IF wy2 < iy2 THEN iy2 = wy2
                IF ix1 > ix2 OR iy1 > iy2 THEN
                        m = m + 1
                        RPut d, m, fx1, fy1, fx2, fy2
                ELSE
                        IF drawit THEN
                                ClipOn ix1, iy1, ix2, iy2
                                WinDrwMng CW
                                ClipOff
                        END IF
                        IF fy1 < iy1 THEN m = m + 1: RPut d, m, fx1, fy1, fx2, iy1 - 1
                        IF iy2 < fy2 THEN m = m + 1: RPut d, m, fx1, iy2 + 1, fx2, fy2
                        IF fx1 < ix1 THEN m = m + 1: RPut d, m, fx1, iy1, ix1 - 1, iy2
                        IF ix2 < fx2 THEN m = m + 1: RPut d, m, ix2 + 1, iy1, fx2, iy2
                END IF
        NEXT
        n = m
        c = d
        IF only <> 0 AND CW = only THEN n = 0
NEXT

IF only = 0 THEN
        FOR i = 1 TO n
                DeskFill RL(c, i, 1), RL(c, i, 2), RL(c, i, 3), RL(c, i, 4)
        NEXT
END IF
END SUB

'A list that is full drops the rectangle: part of the area stays unpainted, but
'the program does not stop.
SUB RPut (l, i, x1, y1, x2, y2)
IF i > 64 THEN EXIT SUB
RL(l, i, 1) = x1
RL(l, i, 2) = y1
RL(l, i, 3) = x2
RL(l, i, 4) = y2
END SUB

'Clip all drawing to a screen rectangle. VIEW SCREEN raises error 5 when the
'rectangle is one pixel thick (x1 = x2 or y1 = y2). Such a strip is clipped as a
'two pixel one instead. The pixels of the padding are saved here and put back in
'ClipOff.
SUB ClipOn (x1, y1, x2, y2)
px1 = x1: py1 = y1: px2 = x2: py2 = y2
ClipCol = 0
ClipRow = 0
IF x1 = x2 THEN
        IF x2 < 639 THEN px2 = x2 + 1 ELSE px1 = x1 - 1
END IF
IF y1 = y2 THEN
        IF y2 < 479 THEN py2 = y2 + 1 ELSE py1 = y1 - 1
END IF
IF px1 <> x1 OR px2 <> x2 THEN
        IF px1 <> x1 THEN ClipColX = px1 ELSE ClipColX = px2
        ClipColY = py1
        GET (ClipColX, py1)-(ClipColX, py2), Scratch
        ClipCol = 1
END IF
IF py1 <> y1 OR py2 <> y2 THEN
        IF py1 <> y1 THEN ClipRowY = py1 ELSE ClipRowY = py2
        ClipRowX = x1
        GET (x1, ClipRowY)-(x2, ClipRowY), Scratch(1000)
        ClipRow = 1
END IF
ClipLX1 = px1: ClipLY1 = py1: ClipLX2 = px2: ClipLY2 = py2
ClipActive = -1
gView px1, py1, px2, py2
END SUB

SUB ClipOff
ClipActive = 0
ClipLX1 = 0: ClipLY1 = 0: ClipLX2 = 639: ClipLY2 = 479
gViewOff
IF ClipCol THEN PUT (ClipColX, ClipColY), Scratch, PSET
IF ClipRow THEN PUT (ClipRowX, ClipRowY), Scratch(1000), PSET
ClipCol = 0
ClipRow = 0
END SUB

'Copy the pixels of a screen rectangle by (dx, dy). Source and destination are
'both on the screen. GET and PUT work on bands that fit one buffer; the bands go
'in the direction that never overwrites rows still to be read.
SUB BlitMove (x1, y1, x2, y2, dx, dy)
rowbytes = 4 * (((x2 - x1 + 1) + 7) \ 8)
rows = 8000 \ rowbytes
IF rows < 1 THEN rows = 1
IF dy > 0 THEN
        by2 = y2
        DO WHILE by2 >= y1
                by1 = by2 - rows + 1
                IF by1 < y1 THEN by1 = y1
                gGet x1, by1, x2, by2
                gPut x1 + dx, by1 + dy
                by2 = by1 - 1
        LOOP
ELSE
        by1 = y1
        DO WHILE by1 <= y2
                by2 = by1 + rows - 1
                IF by2 > y2 THEN by2 = y2
                gGet x1, by1, x2, by2
                gPut x1 + dx, by1 + dy
                by1 = by2 + 1
        LOOP
END IF
END SUB

'Paint a rectangle except for another rectangle inside or across it.
SUB RepaintMinus (x1, y1, x2, y2, dx1, dy1, dx2, dy2)
IF dx2 < x1 OR dx1 > x2 OR dy2 < y1 OR dy1 > y2 THEN
        RepaintRect x1, y1, x2, y2
        EXIT SUB
END IF
IF y1 < dy1 THEN RepaintRect x1, y1, x2, dy1 - 1
IF y2 > dy2 THEN RepaintRect x1, dy2 + 1, x2, y2
top = y1
IF dy1 > top THEN top = dy1
bot = y2
IF dy2 < bot THEN bot = dy2
IF x1 < dx1 THEN RepaintRect x1, top, dx1 - 1, bot
IF x2 > dx2 THEN RepaintRect dx2 + 1, top, x2, bot
END SUB

'Wait for the start of the vertical retrace, so a repaint starts right after the
'monitor picked up the previous frame. Gives up after 50 ms in case the port
'does not change (some emulators).
SUB WaitRetrace
IF NoSync THEN EXIT SUB
t# = TIMER
DO WHILE (INP(&H3DA) AND 8)
        IF ABS(TIMER - t#) > .05 THEN EXIT SUB
LOOP
DO UNTIL (INP(&H3DA) AND 8)
        IF ABS(TIMER - t#) > .05 THEN EXIT SUB
LOOP
END SUB
