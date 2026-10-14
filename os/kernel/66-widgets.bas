'Shared widget looks: a push button and a caption.

'A push button in a rectangle, up or down. Retained buttons (CtlDraw) and
'immediate ones (UiButton) both come here.
SUB DrawPush (x1, y1, x2, y2, cap$, down)
nudge = 0
IF down THEN hi = 2: lo = 15: nudge = 1 ELSE hi = 15: lo = 2
gFill x1 + 2, y1 + 2, x2 - 2, y2 - 2, 3
gLine x1 + 1, y1 + 1, x2 - 2, y1 + 1, hi
gLine x1 + 1, y1 + 2, x1 + 1, y2 - 2, hi
gLine x1 + 1, y2 - 1, x2 - 1, y2 - 1, lo
gLine x2 - 1, y1 + 1, x2 - 1, y2 - 2, lo
gBox x1, y1, x2, y2, 1
w = x2 - x1 + 1
h = y2 - y1 + 1
CtlCap cap$, x1 + (w - LEN(cap$) * 8) \ 2 + nudge, y1 + (h - 16) \ 2 - 1 + nudge, w, 3
END SUB

'Control text in black on the background bg.
SUB CtlCap (t$, x, y, w, bg)
CoutBg = bg
cout t$, x, y, 0, w, 0
CoutBg = -1
END SUB
