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
gWrites = gWrites + CLNG(ClipSpan(x1, x2, gVX1, gVX2)) * ClipSpan(y1, y2, gVY1, gVY2)
LINE (x1, y1)-(x2, y2), c, BF
END SUB

SUB gBox (x1, y1, x2, y2, c)
n& = CLNG(ClipSpan(x1, x2, gVX1, gVX2)) * ClipSpan(y1, y2, gVY1, gVY2)
IF x2 - x1 >= 2 AND y2 - y1 >= 2 THEN
        n& = n& - CLNG(ClipSpan(x1 + 1, x2 - 1, gVX1, gVX2)) * ClipSpan(y1 + 1, y2 - 1, gVY1, gVY2)
END IF
gWrites = gWrites + n&
LINE (x1, y1)-(x2, y2), c, B
END SUB

SUB gLine (x1, y1, x2, y2, c)
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

SUB gPset (x, y, c)
IF x >= gVX1 AND x <= gVX2 AND y >= gVY1 AND y <= gVY2 THEN gWrites = gWrites + 1
PSET (x, y), c
END SUB
