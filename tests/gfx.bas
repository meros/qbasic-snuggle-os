'Counting version of the drawing layer. It draws as the real one does and
'counts the pixels written inside the current clip (gWrites).
SUB gView (x1, y1, x2, y2)
gVX1 = x1: gVY1 = y1: gVX2 = x2: gVY2 = y2
VIEW SCREEN (x1, y1)-(x2, y2)
END SUB

SUB gViewOff
gVX1 = 0: gVY1 = 0: gVX2 = 639: gVY2 = 479
VIEW
END SUB

SUB gFill (x1, y1, x2, y2, c)
IF Outside(x1, y1, x2, y2) THEN EXIT SUB
gCalls = gCalls + 1
gWrites = gWrites + CLNG(ClipSpan(x1, x2, gVX1, gVX2)) * ClipSpan(y1, y2, gVY1, gVY2)
LINE (x1, y1)-(x2, y2), c, BF
END SUB

SUB gBox (x1, y1, x2, y2, c)
IF Outside(x1, y1, x2, y2) THEN EXIT SUB
gCalls = gCalls + 1
n& = CLNG(ClipSpan(x1, x2, gVX1, gVX2)) * ClipSpan(y1, y2, gVY1, gVY2)
IF x2 - x1 >= 2 AND y2 - y1 >= 2 THEN
        n& = n& - CLNG(ClipSpan(x1 + 1, x2 - 1, gVX1, gVX2)) * ClipSpan(y1 + 1, y2 - 1, gVY1, gVY2)
END IF
gWrites = gWrites + n&
LINE (x1, y1)-(x2, y2), c, B
END SUB

SUB gLine (x1, y1, x2, y2, c)
IF Outside(x1, y1, x2, y2) THEN EXIT SUB
gCalls = gCalls + 1
IF y1 = y2 THEN
        IF y1 >= gVY1 AND y1 <= gVY2 THEN gWrites = gWrites + ClipSpan(x1, x2, gVX1, gVX2)
ELSEIF x1 = x2 THEN
        IF x1 >= gVX1 AND x1 <= gVX2 THEN gWrites = gWrites + ClipSpan(y1, y2, gVY1, gVY2)
ELSE
        dx = ABS(x2 - x1): dy = ABS(y2 - y1)
        IF dx > dy THEN gWrites = gWrites + dx + 1 ELSE gWrites = gWrites + dy + 1
END IF
LINE (x1, y1)-(x2, y2), c
END SUB

SUB gCircle (x, y, r, c)
IF Outside(x - r, y - r, x + r, y + r) THEN EXIT SUB
gCalls = gCalls + 1
gWrites = gWrites + 6 * r
CIRCLE (x, y), r, c
END SUB

SUB gPset (x, y, c)
IF Outside(x, y, x, y) THEN EXIT SUB
gCalls = gCalls + 1
gPsets = gPsets + 1
IF x >= gVX1 AND x <= gVX2 AND y >= gVY1 AND y <= gVY2 THEN gWrites = gWrites + 1
PSET (x, y), c
END SUB

SUB gGet (x1, y1, x2, y2)
gCalls = gCalls + 1
gGetW = x2 - x1 + 1
gGetH = y2 - y1 + 1
GET (x1, y1)-(x2, y2), BlitBuf
END SUB

SUB gPut (x, y)
gCalls = gCalls + 1
gWrites = gWrites + CLNG(gGetW) * gGetH
PUT (x, y), BlitBuf, PSET
END SUB

SUB gGlyph (gx, gy, num, colo, st)
IF st >= 0 AND num >= 32 AND num <= 127 THEN
        IF ClipActive THEN
                inside = gx >= ClipLX1 AND gx + 7 <= ClipLX2 AND gy >= ClipLY1 AND gy + 15 <= ClipLY2
        ELSE
                inside = gx >= 0 AND gx + 7 <= 639 AND gy >= 0 AND gy + 15 <= 479
        END IF
        IF inside THEN
                gCalls = gCalls + 1
                gWrites = gWrites + 128
                PUT (gx, gy), SprData((st * 96 + num - 32) * 34), PSET
                EXIT SUB
        END IF
END IF
k = GlyphFirst(num)
IF ClipActive THEN
        inside = gx >= ClipLX1 AND gx + 7 <= ClipLX2 AND gy >= ClipLY1 AND gy + 15 <= ClipLY2
ELSE
        inside = gx >= 0 AND gx + 7 <= 639 AND gy >= 0 AND gy + 15 <= 479
END IF
FOR n = 1 TO GlyphRuns(num)
        v = GlyphData(k)
        k = k + 1
        ry = gy + v \ 64
        x0 = gx + ((v \ 8) AND 7)
        x1 = gx + (v AND 7)
        IF inside OR NOT Outside(x0, ry, x1, ry) THEN
                gCalls = gCalls + 1
                gWrites = gWrites + (x1 - x0 + 1)
                LINE (x0, ry)-(x1, ry), colo
        END IF
NEXT
END SUB

SUB gGetSprite (so)
GET (0, 0)-(7, 15), SprData(so)
END SUB
