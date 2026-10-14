'How a window looks: frame, title bar and its buttons.

SUB DrwBtn (x, y, w, h)
Col1 = 1: Col2 = 3
gFill x + 1, y + 1, x + w - 1, y + h - 1, 2
gPset x + w, y, 2
gPset x, y + h, 2
gLine x, y, x, y + h - 1, Col2
gLine x + 1, y, x + h - 1, y, Col2
gLine x + w, y + h, x + 1, y + h, Col1
gLine x + w, y + h - 1, x + w, y + 1, Col1

END SUB

'A title bar button with its picture: 1 close, 2 maximise, 3 roll up.
SUB WinBtn (x, y, kind)
DrwBtn x, y, TtlHeight - 6, TtlHeight - 6
SELECT CASE kind
CASE 1
        gBox x + 5, y + 2, x + 7, y + 6, 1
        gBox x + 5, y + 8, x + 7, y + 10, 1
        gLine x + 6, y + 3, x + 6, y + 5, 6
        gPset x + 6, y + 9, 6
CASE 2
        gLine x + 2, y + 4, x + 10, y + 4, 1
        gLine x + 3, y + 3, x + 9, y + 3, 6
        gBox x + 2, y + 2, x + 10, y + 10, 1
        gFill x + 3, y + 5, x + 9, y + 9, 15
CASE ELSE
        gLine x + 3, y + 6, x + 9, y + 6, 6
        gBox x + 2, y + 5, x + 10, y + 7, 1
END SELECT
END SUB

SUB WinDrw (text$, x, y, w, h, state)
        IF NOT Outside(x, y, x + w, y + TtlHeight) THEN
                WinDrwTtl x, y, x + w, y + TtlHeight
                Lengh = w - TtlHeight * 3 - 2 - 5
                CharsVis = (Lengh - (Lenght MOD 8)) / 8
                print$ = MID$(text$, 1, CharsVis)
                IF LEN(text$) <> LEN(print$) AND LEN(print$) >= 3 THEN MID$(print$, LEN(print$) - 2, 3) = "..."
                CoutBg = 6
                cout print$, x + 5, y, 2, Lengh + 8, 0
                CoutBg = -1

                FOR b = 1 TO 3
                        WinBtn x + w - TtlHeight * b, y + 3, b
                NEXT
        END IF
        IF state <> 0 THEN
                IF NOT Outside(x, y + TtlHeight + 1, x + w, y + h) THEN WinDrwBrd x, y + TtlHeight + 1, x + w, y + h
        END IF
END SUB

SUB WinDrwBrd (x1, y1, x2, y2)
'Outer ring, shaded top/left (3) and bottom/right (1), corners (2)
gLine x1, y1, x2 - 1, y1, 3
gPset x2, y1, 2
gLine x1, y1 + 1, x1, y2 - 1, 3
gPset x1, y2, 2
gLine x2, y1 + 1, x2, y2, 1
gLine x1 + 1, y2, x2 - 1, y2, 1
'Middle ring
gBox x1 + 1, y1 + 1, x2 - 1, y2 - 1, 2
'Inner ring, with the shadow on the right and bottom
gLine x1 + 2, y1 + 2, x2 - 3, y1 + 2, 1
gPset x2 - 2, y1 + 2, 2
gLine x1 + 2, y1 + 3, x1 + 2, y2 - 3, 1
gPset x1 + 2, y2 - 2, 2
gLine x2 - 2, y1 + 3, x2 - 2, y2 - 2, 3
gLine x1 + 3, y2 - 2, x2 - 3, y2 - 2, 3
'Client area
IF x1 + 3 <= x2 - 3 AND y1 + 3 <= y2 - 3 AND NOT ClientOpaque THEN gFill x1 + 3, y1 + 3, x2 - 3, y2 - 3, 15

END SUB

SUB WinDrwMng (who)
GetStats who, text$, x, y, w, h, state
'An app that paints all of its client area (manifest opaque) needs no white
'fill under it, so a repaint writes each of its pixels once.
ClientOpaque = AppOpaque(HGet(who, WfApp))
WinDrw text$, x, y, w, h, state
ClientOpaque = 0
IF state <> 0 THEN
        CtlDrawAll who
        UiRun who, 0
END IF
END SUB

SUB WinDrwTtl (x1, y1, x2, y2)
gFill x1 + 1, y1 + 1, x2 - 1, y2 - 1, 6
gPset x2, y1, 6
gPset x1, y2, 6

gLine x1, y1, x2 - 1, y1, 7
gLine x1, y1 + 1, x1, y2 - 1, 7

gLine x1 + 1, y2, x2, y2, 5
gLine x2, y1 + 1, x2, y2 - 1, 5

END SUB
