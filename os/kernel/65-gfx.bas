'The drawing layer: the only code that draws (the tests swap it for a counting one).

'-1 when a rectangle (or the bounding box of a line) lies completely outside the
'clip, or outside the screen when no clip is set. The drawing layer skips such
'calls: QBasic's LINE leaves a stray pixel in the bottom left corner of the view
'for a box that is entirely below and left of it.
FUNCTION Outside (x1, y1, x2, y2)
xl = x1: xh = x2
IF xl > xh THEN xl = x2: xh = x1
yl = y1: yh = y2
IF yl > yh THEN yl = y2: yh = y1
Outside = (xh < ClipLX1 OR xl > ClipLX2 OR yh < ClipLY1 OR yl > ClipLY2)
END FUNCTION

'@@GFX-BEGIN
'The only place that draws. The tests replace this block with a counting version.
SUB gView (x1, y1, x2, y2)
VIEW SCREEN (x1, y1)-(x2, y2)
END SUB

SUB gViewOff
VIEW
END SUB

SUB gFill (x1, y1, x2, y2, c)
IF Outside(x1, y1, x2, y2) THEN EXIT SUB
LINE (x1, y1)-(x2, y2), c, BF
END SUB

SUB gBox (x1, y1, x2, y2, c)
IF Outside(x1, y1, x2, y2) THEN EXIT SUB
LINE (x1, y1)-(x2, y2), c, B
END SUB

SUB gLine (x1, y1, x2, y2, c)
IF Outside(x1, y1, x2, y2) THEN EXIT SUB
LINE (x1, y1)-(x2, y2), c
END SUB

SUB gPset (x, y, c)
IF Outside(x, y, x, y) THEN EXIT SUB
PSET (x, y), c
END SUB

'@if widgets
SUB gCircle (x, y, r, c)
IF Outside(x - r, y - r, x + r, y + r) THEN EXIT SUB
CIRCLE (x, y), r, c
END SUB
'@endif

SUB gGetSprite (so)
GET (0, 0)-(7, 15), SprData(so)
END SUB

SUB gPutSpr (x, y, so)
PUT (x, y), SprData(so), PSET
END SUB

SUB gGet (x1, y1, x2, y2)
GET (x1, y1)-(x2, y2), Scratch
END SUB

SUB gPut (x, y)
PUT (x, y), Scratch, PSET
END SUB
'@@GFX-END
