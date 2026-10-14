'The drawing and repaint code as it was in 1999, kept as the oracle: the same
'LINE calls in the same order, and the erase-and-redraw move.
SUB RefDrwBtn (x, y, w, h, up)
IF up = 1 THEN Col1 = 1: Col2 = 3 ELSE Col2 = 1: Col1 = 3

gFill x, y, x + w, y + h, 2
gLine x, y, x, y + h - 1, Col2
gLine x, y, x + h - 1, y, Col2
gLine x + w, y + h, x + 1, y + h, Col1
gLine x + w, y + h, x + w, y + 1, Col1
END SUB

SUB RefWinDrwBrd (x1, y1, x2, y2)
gFill x1, y1, x2, y2, 15
gBox x1, y1, x2, y2, 3
gBox x1 + 1, y1 + 1, x2 - 1, y2 - 1, 2
gBox x1 + 2, y1 + 2, x2 - 2, y2 - 2, 1
gLine x2 - 2, y2 - 2, x2 - 2, y1 + 3, 3
gLine x2 - 2, y2 - 2, x1 + 3, y2 - 2, 3
gLine x2, y2, x2, y1 + 1, 1
gLine x2, y2, x1 + 1, y2, 1
gLine x2, y1, x2 - 2, y1 + 2, 2
gLine x1, y2, x1 + 2, y2 - 2, 2
END SUB

SUB RefWinDrwTtl (x1, y1, x2, y2)
gFill x1, y1, x2, y2, 6
gLine x1, y1, x2 - 1, y1, 7
gLine x1, y1, x1, y2 - 1, 7
gLine x2, y2, x1 + 1, y2, 5
gLine x2, y2, x2, y1 + 1, 5
END SUB

SUB RefWinDrw (text$, x, y, w, h, state, btnA, btnB, btnC)
        RefWinDrwTtl x, y, x + w, y + TtlHeight
                Lengh = w - TtlHeight * 3 - 2 - 5
                CharsVis = (Lengh - (Lenght MOD 8)) / 8
                print$ = MID$(text$, 1, CharsVis)
                IF LEN(text$) <> LEN(print$) AND LEN(print$) >= 3 THEN MID$(print$, LEN(print$) - 2, 3) = "..."
                cout print$, x + 5, y, 2, Lengh + 8, 0

                RefDrwBtn x + w - TtlHeight * 3, y + 3, TtlHeight - 6, TtlHeight - 6, btnA
                RefDrwBtn x + w - TtlHeight * 2, y + 3, TtlHeight - 6, TtlHeight - 6, btnB
                RefDrwBtn x + w - TtlHeight * 1, y + 3, TtlHeight - 6, TtlHeight - 6, btnC

                MinButton x + w - TtlHeight * 3, y + 3
                MaxButton x + w - TtlHeight * 2, y + 3
                QuitButton x + w - TtlHeight * 1, y + 3
        IF state <> 0 THEN RefWinDrwBrd x, y + TtlHeight + 1, x + w, y + h
END SUB

SUB RefWinDrwMng (who)
GetStats who, text$, x, y, w, h, state
RefWinDrw text$, x, y, w, h, state, 1, 1, 1
IF state <> 0 THEN
        CtlDrawAll who
        UiPaint who
END IF
END SUB

'Whole screen, back to front: the reference image for any window state.
SUB RefPaintAll
gFill 0, 0, 639, 479, 4
IconsDraw
FOR Cyc = WNumber TO 1 STEP -1
        RefWinDrwMng WOrder(Cyc)
NEXT
END SUB

SUB LegacyUnDrw (who)
GetStats who, crap$, x, y, w, h, state
IF state <> 0 THEN height = h ELSE height = TtlHeight
gFill x, y, x + w, y + height, 4

DIM ReDrawn(WNumber) AS INTEGER

ReDrawn(who) = 1

FOR Cyc = WNumber TO 1 STEP -1
        CW = WOrder(Cyc)
        IF CW <> who THEN
        GetStats CW, crap$, x, y, w, h, state

        FOR TCW = 1 TO WNumber

                GetStats TCW, crap$, tx, ty, tw, th, tstate

                IF x + w >= tx AND x <= tx + tw AND y + h >= ty AND y <= ty + th AND TCW <> CW AND ReDrawn(TCW) THEN

                ReDrawn(CW) = 1

                RefWinDrwMng CW
                EXIT FOR
                END IF

        NEXT
        END IF
NEXT
END SUB

'One drag step the old way: erase, repaint what was below, draw the window again.
SUB LegacyMoveTo (who, nx, ny)
LegacyUnDrw who
HSet who, WfX, nx
HSet who, WfY, ny
RefWinDrwMng who
END SUB
