'SNUGGLE OS ALPHA!
'Copyright 1999 Alexander Schrab
'Thanks to:
'UPA for help and ideas
'Mark K. Kim for the Vmouse routine (Couldn't have done it without you!!)


DECLARE FUNCTION CheckIfWinBtn% (who%)
DECLARE SUB refresh ()
DECLARE SUB StartXYDrag (what%, who%)
DECLARE FUNCTION CheckIfBorder% (what%, who%)
DECLARE SUB WinPutTop (who%)
DECLARE FUNCTION CheckIfWinArea% (who%)
DECLARE SUB WinMakeHighest (num%)
DECLARE SUB WinMoveTo (who%, nx%, ny%)
DECLARE SUB WinSizeTo (who%, nw%, nh%)
DECLARE SUB WinSetState (who%, st%)
DECLARE SUB WinRect (who%, x1%, y1%, x2%, y2%)
DECLARE SUB RepaintRect (x1%, y1%, x2%, y2%)
DECLARE SUB RepaintChange (ox1%, oy1%, ox2%, oy2%, nx1%, ny1%, nx2%, ny2%)
DECLARE SUB WaitRetrace ()
DECLARE SUB ClipOn (x1%, y1%, x2%, y2%)
DECLARE SUB ClipOff ()
DECLARE FUNCTION CtlAdd% (win%, kind%, x%, y%, w%, h%, cap$)
DECLARE SUB CtlReset ()
DECLARE SUB CtlRect (id%, x1%, y1%, x2%, y2%)
DECLARE FUNCTION CtlVisible% (id%)
DECLARE SUB CtlDraw (id%)
DECLARE SUB CtlDrawAll (who%)
DECLARE SUB CtlRedraw (id%)
DECLARE FUNCTION CtlHit% (who%, mx%, my%)
DECLARE FUNCTION CtlAt% (mx%, my%)
DECLARE SUB CtlActivate (id%)
DECLARE SUB CtlSelect (id%)
DECLARE SUB CtlTrack (id%)
DECLARE SUB CtlKey (k$)
DECLARE SUB CtlSetFocus (id%)
DECLARE SUB CtlSetText (id%, t$)
DECLARE FUNCTION CtlGetText$ (id%)
DECLARE SUB CtlSetChecked (id%, v%)
DECLARE FUNCTION CtlGetChecked% (id%)
DECLARE SUB gCircle (x%, y%, r%, c%)
DECLARE SUB gGet (x1%, y1%, x2%, y2%)
DECLARE SUB gGlyph (gx%, gy%, num%, colo%, st%)
DECLARE SUB gGetSprite (so%)
DECLARE SUB gPut (x%, y%)
DECLARE SUB BlitMove (x1%, y1%, x2%, y2%, dx%, dy%)
DECLARE SUB RepaintMinus (x1%, y1%, x2%, y2%, dx1%, dy1%, dx2%, dy2%)
DECLARE FUNCTION Outside% (x1%, y1%, x2%, y2%)
DECLARE SUB gView (x1%, y1%, x2%, y2%)
DECLARE SUB gViewOff ()
DECLARE SUB gFill (x1%, y1%, x2%, y2%, c%)
DECLARE SUB gBox (x1%, y1%, x2%, y2%, c%)
DECLARE SUB gLine (x1%, y1%, x2%, y2%, c%)
DECLARE SUB gPset (x%, y%, c%)
DECLARE SUB StartDrag (who%)
DECLARE SUB MouseCall (ax%, bx%, cx%, dx%)
DECLARE SUB Pal (i%, r%, g%, b%)
DECLARE SUB mouse.getpos (x%, y%)
DECLARE FUNCTION CheckIfTitle% (who%)
DECLARE SUB NewWin (text$, x%, y%, w%, h%)
DECLARE SUB DrwBtn (x%, y%, w%, h%, up%)
DECLARE SUB GetStats (who%, text$, x%, y%, w%, h%, state%)
DECLARE SUB WinDrwMng (who%)
DECLARE SUB WinDrw (text$, x%, y%, w%, h%, state%, btnA%, btnB%, ctnC%)
DECLARE SUB MaxButton (x%, y%)
DECLARE SUB MinButton (x%, y%)
DECLARE SUB QuitButton (x%, y%)
DECLARE SUB cout (text$, sx%, sy%, colo%, Lengh%, break%)
DECLARE SUB Init ()
DECLARE SUB CoutSetup ()
DECLARE SUB mouse.show ()
DECLARE SUB mouse.hide ()
DECLARE FUNCTION mouse.enable% ()
DECLARE FUNCTION mouse.getbutton% ()
DECLARE SUB WinDrwBrd (x1%, y1%, x2%, y2%)
DECLARE SUB WinDrwTtl (x1%, y1%, x2%, y2%)
'***************
CONST LB = &H1      'constant for left button
'***************
CONST TtlHeight = 18
'Controls
CONST CtlMax = 32
CONST CtlLabel = 1
CONST CtlButton = 2
CONST CtlCheck = 3
CONST CtlRadio = 4
CONST CtlText = 5
TYPE CtlRec
        kind AS INTEGER         'CtlLabel .. CtlText
        win AS INTEGER          'window that holds it
        x AS INTEGER            'position inside the window's client area
        y AS INTEGER
        w AS INTEGER
        h AS INTEGER
        chk AS INTEGER          'checkbox and radio: 0 or 1
        grp AS INTEGER          'radio buttons with the same window and group exclude each other
        cap AS STRING * 40      'caption, or the text of a text box
END TYPE
DIM SHARED GlyphFirst(255) AS INTEGER   'glyph n is GlyphRuns(n) horizontal runs, from GlyphData(GlyphFirst(n))
DIM SHARED GlyphRuns(255) AS INTEGER    'a run is packed as row * 64 + first column * 8 + last column
DIM SHARED GlyphData(3600) AS INTEGER   'the screen font needs 3167 runs
DIM SHARED GlyphBuf(40) AS INTEGER
DIM SHARED GlyphTop AS INTEGER

DIM SHARED WNMax AS INTEGER
WNMax = 10
DIM SHARED WNumber AS INTEGER
DIM SHARED WGData(WNMax, 6) AS INTEGER
DIM SHARED WTData(WNMax) AS STRING
DIM SHARED WOrder(WNMax) AS INTEGER
DIM SHARED FreeRX1(64) AS INTEGER   'Repaint work list: rectangles still to paint
DIM SHARED FreeRY1(64) AS INTEGER
DIM SHARED FreeRX2(64) AS INTEGER
DIM SHARED FreeRY2(64) AS INTEGER
DIM SHARED NextRX1(64) AS INTEGER   'the list being built for the next window
DIM SHARED NextRY1(64) AS INTEGER
DIM SHARED NextRX2(64) AS INTEGER
DIM SHARED NextRY2(64) AS INTEGER
DIM SHARED ClipCol AS INTEGER           'a clip one pixel thick is padded; these save the pixels
DIM SHARED ClipColX AS INTEGER          'the padding covers, so ClipOff can put them back
DIM SHARED ClipColY AS INTEGER
DIM SHARED ClipRow AS INTEGER
DIM SHARED ClipRowX AS INTEGER
DIM SHARED ClipRowY AS INTEGER
DIM SHARED Ctl(CtlMax) AS CtlRec
DIM SHARED CtlCount AS INTEGER
DIM SHARED VisOld(CtlMax) AS INTEGER           'which controls were drawn before a resize
DIM SHARED CtlFocus AS INTEGER          'text box that receives the keys, 0 for none
DIM SHARED CtlDown AS INTEGER           'button that is held down, 0 for none
DIM SHARED CtlEvent AS INTEGER          'control that was clicked or accepted, 0 for none
DIM SHARED SprData(9800) AS INTEGER     'ready-made glyphs 32 to 127 for each text style: PUT, no LINEs
DIM SHARED SprFg(2) AS INTEGER          'text styles: colour of the glyph and of the background behind it
DIM SHARED SprBg(2) AS INTEGER
DIM SHARED CoutBg AS INTEGER            'background colour behind the text cout draws, -1 for unknown
DIM SHARED NoSync AS INTEGER           'the tests set it: no wait for the retrace
DIM SHARED BlitBuf(4100) AS INTEGER      'one band of screen rows (8000 bytes), for BlitMove
DIM SHARED ClipActive AS INTEGER        'cout skips glyphs outside the clip
DIM SHARED ClipLX1 AS INTEGER
DIM SHARED ClipLY1 AS INTEGER
DIM SHARED ClipLX2 AS INTEGER
DIM SHARED ClipLY2 AS INTEGER
DIM SHARED ClipColBuf(1000) AS INTEGER  '1 x 480 pixels, four planes
DIM SHARED ClipRowBuf(170) AS INTEGER   '640 x 1 pixels
DIM SHARED MouseAsm AS STRING    'machine code for the mouse driver call
DIM SHARED MouseOK AS INTEGER
DIM SHARED MouseVis AS INTEGER


DEFINT A-Z
'@@RUN-BEGIN
SCREEN 12
enabled% = mouse.enable
mouse.show
Init
CLS

NewWin "Alfa", 90, 90, 300, 70
NewWin "Beta", 100, 100, 300, 70
NewWin "Welcome to the future", 120, 120, 300, 100
NewWin "Controls", 330, 40, 290, 230
cw0 = WNumber
cName = CtlAdd(cw0, CtlText, 70, 4, 200, 22, "snuggle")
cLabel = CtlAdd(cw0, CtlLabel, 8, 6, 60, 16, "Name:")
cSound = CtlAdd(cw0, CtlCheck, 8, 38, 170, 16, "Enable sound")
cRed = CtlAdd(cw0, CtlRadio, 8, 64, 100, 16, "Red")
cGreen = CtlAdd(cw0, CtlRadio, 8, 84, 100, 16, "Green")
cBlue = CtlAdd(cw0, CtlRadio, 8, 104, 100, 16, "Blue")
cOk = CtlAdd(cw0, CtlButton, 8, 140, 80, 26, "OK")
cClear = CtlAdd(cw0, CtlButton, 100, 140, 80, 26, "Clear")
cStatus = CtlAdd(cw0, CtlLabel, 8, 178, 262, 16, "Ready")
CtlSetChecked cRed, 1
refresh

DO
IF mouse.getbutton = LB THEN
FOR Cyc = 1 TO WNumber
CW = WOrder(Cyc)
GetStats CW, crap$, wx, wy, ww, wh, wstate
        IF CheckIfWinBtn(CW) > 0 THEN
                LOCATE 1, 1
                DO: LOOP WHILE mouse.getbutton = LB
                WinPutTop CW
                SELECT CASE CheckIfWinBtn(CW)
                CASE 1
                CASE 2
                        IF WGData(CW, 5) <> 2 THEN WinSetState CW, 2 ELSE WinSetState CW, 1
                CASE 3
                        IF WGData(CW, 5) <> 0 THEN WinSetState CW, 0 ELSE WinSetState CW, 1
                CASE ELSE
                END SELECT
                EXIT FOR
        END IF
        IF CheckIfTitle(CW) THEN
                CtlSetFocus 0
                WinPutTop CW
                IF wstate <> 2 THEN StartDrag CW
                EXIT FOR
        END IF
        Ext = 0
        FOR temp = 3 TO 1 STEP -1
        IF CheckIfBorder(temp, CW) THEN
                WinPutTop CW
                IF wstate <> 2 THEN StartXYDrag temp, CW
                Ext = 1
        END IF
        NEXT
        IF Ext = 1 THEN EXIT FOR
        mouse.getpos cmx, cmy
        cid = CtlHit(CW, cmx, cmy)
        IF cid > 0 THEN
                WinPutTop CW
                CtlTrack cid
                EXIT FOR
        END IF
        IF CheckIfWinArea(CW) THEN
                CtlSetFocus 0
                DO: LOOP WHILE mouse.getbutton = LB
                WinPutTop CW
                EXIT FOR
        END IF
NEXT
END IF
k$ = INKEY$
IF CtlFocus <> 0 THEN
        CtlKey k$
        k$ = ""
END IF
IF CtlEvent <> 0 THEN
        SELECT CASE CtlEvent
        CASE cOk
                CtlSetText cStatus, "Hello, " + CtlGetText$(cName)
        CASE cClear
                CtlSetText cName, ""
                CtlSetText cStatus, "Ready"
        END SELECT
        CtlEvent = 0
END IF
IF UCASE$(k$) = "R" THEN refresh
LOOP UNTIL UCASE$(k$) = "Q"
'@@RUN-END

'@@HIT-BEGIN
FUNCTION CheckIfBorder (what, who)
GetStats who, crap$, wx, wy, ww, wh, wstate
mouse.getpos x, y
SELECT CASE what
CASE 1
MinX = wx + ww - 3
MaxX = wx + ww
MinY = wy + 19
MaxY = wy + wh
CASE 2
MinX = wx
MaxX = wx + ww
MinY = wy + wh - 3
MaxY = wy + wh
CASE 3
MinX = wx + ww - 3
MaxX = wx + ww
MinY = wy + wh - 3
MaxY = wy + wh
CASE ELSE
END SELECT
IF x >= MinX AND x <= MaxX AND y >= MinY AND y <= MaxY THEN
CheckIfBorder = 1
END IF
END FUNCTION

FUNCTION CheckIfTitle (who)
mouse.getpos mx, my
GetStats who, crap$, x, y, w, h, state
IF mx >= x AND mx <= x + w AND my >= y AND my <= y + TtlHeight THEN CheckIfTitle = 1
END FUNCTION

FUNCTION CheckIfWinArea (who)
mouse.getpos mx, my
GetStats who, crap$, x, y, w, h, state

IF state = 0 THEN
CheckIfWinArea = 0
ELSE
IF mx >= x AND mx <= x + w AND my >= y AND my <= y + h THEN CheckIfWinArea = 1
END IF

END FUNCTION

FUNCTION CheckIfWinBtn (who)
mouse.getpos mx, my
GetStats who, crap$, x, y, w, h, state

FOR CW = 1 TO 3
MinX = x + w - TtlHeight * CW
MinY = y + 3
MaxX = MinX + TtlHeight - 6
MaxY = MinY + TtlHeight - 6
IF mx >= MinX AND mx <= MaxX AND my >= MinY AND my <= MaxY THEN
        CheckIfWinBtn = CW
        EXIT FOR
END IF
NEXT

END FUNCTION
'@@HIT-END

SUB cout (text$, sx, sy, colo, Lengh, break)
DIM charlengh AS INTEGER

'A known background and colour pair has ready-made glyphs.
st = -1
IF CoutBg >= 0 THEN
        FOR i = 0 TO 2
                IF SprFg(i) = colo AND SprBg(i) = CoutBg THEN st = i
        NEXT
END IF

charlengh = (Lengh - (Lengh MOD 8)) / 8
RowChar = 0
FOR Char = 1 TO LEN(text$)
        RowChar = RowChar + 1
        IF RowChar > charlengh THEN
        IF break = 1 THEN sy = sy + 16: RowChar = 1 ELSE GOTO stopthis
        END IF
        num = ASC(MID$(text$, Char, 1))

        gx = sx + (RowChar - 1) * 8
        IF ClipActive THEN
                vis = gx + 7 >= ClipLX1 AND gx <= ClipLX2 AND sy + 16 >= ClipLY1 AND sy + 1 <= ClipLY2
        ELSE
                vis = -1
        END IF
        IF vis THEN gGlyph gx, sy + 1, num, colo, st
NEXT
stopthis:
END SUB

'Read the 8 x 16 glyph of every character from the screen font into runs. The
'glyph is printed in colour 1 (one bit plane), read back with GET, and each row
'of the plane is cut into runs of set pixels.
SUB CoutSetup
COLOR 1
Pal 1, 0, 0, 0

GlyphTop = 0
FOR a = 15 TO 255
        LOCATE 1, 1
        PRINT CHR$(a)
        GET (0, 0)-(7, 15), GlyphBuf
        GlyphFirst(a) = GlyphTop
        FOR r = 0 TO 15
                m = GlyphBuf(2 + r * 2) AND &HFF
                bit = 128
                x0 = -1
                FOR x = 0 TO 8
                        IF (m AND bit) <> 0 THEN
                                IF x0 < 0 THEN x0 = x
                        ELSEIF x0 >= 0 THEN
                                IF GlyphTop < 3600 THEN GlyphData(GlyphTop) = r * 64 + x0 * 8 + x - 1: GlyphTop = GlyphTop + 1
                                x0 = -1
                        END IF
                        bit = bit \ 2
                NEXT
        NEXT
        GlyphRuns(a) = GlyphTop - GlyphFirst(a)
NEXT

'Ready-made glyphs: title text, text on the client area, text on a button.
SprFg(0) = 2: SprBg(0) = 6
SprFg(1) = 0: SprBg(1) = 15
SprFg(2) = 0: SprBg(2) = 3
CoutBg = -1
FOR st = 0 TO 2
        FOR c = 32 TO 127
                gFill 0, 0, 7, 15, SprBg(st)
                gGlyph 0, 0, c, SprFg(st), -1
                spr = (st * 96 + c - 32) * 34
                gGetSprite spr
        NEXT
NEXT

END SUB

SUB Pal (i, r, g, b)
OUT &H3C8, i
OUT &H3C9, r
OUT &H3C9, g
OUT &H3C9, b
END SUB

SUB DrwBtn (x, y, w, h, up)
IF up = 1 THEN Col1 = 1: Col2 = 3 ELSE Col2 = 1: Col1 = 3

gFill x + 1, y + 1, x + w - 1, y + h - 1, 2
gPset x + w, y, 2
gPset x, y + h, 2
gLine x, y, x, y + h - 1, Col2
gLine x + 1, y, x + h - 1, y, Col2
gLine x + w, y + h, x + 1, y + h, Col1
gLine x + w, y + h - 1, x + w, y + 1, Col1

END SUB

SUB GetStats (who, text$, x, y, w, h, state)
text$ = WTData(who)
x = WGData(who, 1)
y = WGData(who, 2)
        IF WGData(who, 3) < 90 THEN WGData(who, 3) = 90
        IF WGData(who, 4) < TtlHeight + 6 THEN WGData(who, 4) = TtlHeight + 6
w = WGData(who, 3)
h = WGData(who, 4)

state = WGData(who, 5)
IF state = 0 THEN h = TtlHeight
IF state = 1 THEN
END IF
IF state = 2 THEN w = 640: h = 480: x = 0: y = 0


END SUB

'@@INIT-BEGIN
SUB Init
CoutSetup
Pal 0, 0, 0, 0
Pal 1, 22, 22, 22
Pal 2, 32, 32, 32
Pal 3, 42, 42, 42
Pal 4, 0, 40, 40
Pal 5, 0, 0, 22
Pal 6, 0, 0, 32
Pal 7, 0, 0, 42
END SUB
'@@INIT-END

SUB MaxButton (x, y)
gLine x + 2, y + 4, x + 10, y + 4, 1
gLine x + 3, y + 3, x + 9, y + 3, 6
gBox x + 2, y + 2, x + 10, y + 10, 1
gFill x + 3, y + 5, x + 9, y + 9, 15
END SUB

SUB MinButton (x, y)
gLine x + 3, y + 6, x + 9, y + 6, 6
gBox x + 2, y + 5, x + 10, y + 7, 1
END SUB

'@@MOUSE-BEGIN
'Mouse driver (int 33h) through a machine-code string and CALL ABSOLUTE. The
'machine code is from Mark K. Kim's Vmouse routine; the five procedures that
'Snuggle OS uses share one call, MouseCall. ax, bx, cx and dx go in and come
'back as the registers after the call.
SUB MouseCall (ax, bx, cx, dx)
ofs = SADD(MouseAsm)
DEF SEG = VARSEG(MouseAsm)
CALL ABSOLUTE(d, d, d, d, ax, bx, cx, dx, 0, ofs)
DEF SEG
END SUB

'-1 when a mouse driver is installed, else 0. Run it before any other mouse call.
FUNCTION mouse.enable%
h$ = "5589E58B5E0E8B07508B5E0C8B07508B5E0A8B0F8B5E088B178B5E068E075B58CD33538B5E0E8907588B5E0C89078B5E0A890F8B5E0889175DCA1200"
MouseAsm = ""
FOR i = 1 TO LEN(h$) STEP 2
        MouseAsm = MouseAsm + CHR$(VAL("&H" + MID$(h$, i, 2)))
NEXT
MouseOK = 0
MouseCall MouseOK, b, c, d
mouse.enable = MouseOK
END FUNCTION

'Buttons that are down: LB for the left button.
FUNCTION mouse.getbutton%
bx = 0
IF MouseOK THEN MouseCall 3, bx, c, d
mouse.getbutton = bx AND 7
END FUNCTION

'Pointer position in pixels.
SUB mouse.getpos (x, y)
IF MouseOK THEN MouseCall 3, b, x, y
END SUB

SUB mouse.hide
IF MouseOK AND MouseVis THEN
        MouseCall 2, b, c, d
        MouseVis = 0
END IF
END SUB

SUB mouse.show
IF MouseOK AND NOT MouseVis THEN
        MouseCall 1, b, c, d
        MouseVis = 1
END IF
END SUB
'@@MOUSE-END

SUB NewWin (text$, x, y, w, h)
WNumber = WNumber + 1
WGData(WNumber, 1) = x
WGData(WNumber, 2) = y
WGData(WNumber, 3) = w
WGData(WNumber, 4) = h
WGData(WNumber, 5) = 1
WGData(WNumber, 0) = 0
WTData(WNumber) = text$
WOrder(WNumber) = WNumber
WinMakeHighest WNumber
END SUB

SUB QuitButton (x, y)
gBox x + 5, y + 2, x + 7, y + 6, 1
gBox x + 5, y + 8, x + 7, y + 10, 1
gLine x + 6, y + 3, x + 6, y + 5, 6
gPset x + 6, y + 9, 6


END SUB

SUB refresh
mouse.hide
RepaintRect 0, 0, 639, 479
mouse.show
END SUB

'@@DRAG-BEGIN
SUB StartDrag (who)
mouse.getpos ox, oy
        x = ox: y = oy
        GetStats who, crap$, wx, wy, ww, wh, wstate
DO
        lx = x: ly = y
        mouse.getpos x, y
        IF lx <> x OR ly <> y THEN WinMoveTo who, wx + (x - ox), wy + (y - oy)
LOOP UNTIL mouse.getbutton <> LB
END SUB

SUB StartXYDrag (what, who)
mouse.getpos ox, oy
        x = ox: y = oy
        GetStats who, crap$, wx, wy, ww, wh, wstate
DO
        lx = x: ly = y
        mouse.getpos x, y
        IF lx <> x OR ly <> y THEN
                nw = ww: nh = wh
                IF what <> 2 THEN nw = ww + (x - ox)
                IF what <> 1 THEN nh = wh + (y - oy)
                WinSizeTo who, nw, nh
        END IF
LOOP UNTIL mouse.getbutton <> LB
END SUB

'@@DRAG-END

SUB WinDrw (text$, x, y, w, h, state, btnA, btnB, btnC)
        IF NOT Outside(x, y, x + w, y + TtlHeight) THEN
                WinDrwTtl x, y, x + w, y + TtlHeight
                Lengh = w - TtlHeight * 3 - 2 - 5
                CharsVis = (Lengh - (Lenght MOD 8)) / 8
                print$ = MID$(text$, 1, CharsVis)
                IF LEN(text$) <> LEN(print$) AND LEN(print$) >= 3 THEN MID$(print$, LEN(print$) - 2, 3) = "..."
                CoutBg = 6
                cout print$, x + 5, y, 2, Lengh + 8, 0
                CoutBg = -1

                DrwBtn x + w - TtlHeight * 3, y + 3, TtlHeight - 6, TtlHeight - 6, btnA
                DrwBtn x + w - TtlHeight * 2, y + 3, TtlHeight - 6, TtlHeight - 6, btnB
                DrwBtn x + w - TtlHeight * 1, y + 3, TtlHeight - 6, TtlHeight - 6, btnC

                MinButton x + w - TtlHeight * 3, y + 3
                MaxButton x + w - TtlHeight * 2, y + 3
                QuitButton x + w - TtlHeight * 1, y + 3
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
IF x1 + 3 <= x2 - 3 AND y1 + 3 <= y2 - 3 THEN gFill x1 + 3, y1 + 3, x2 - 3, y2 - 3, 15

END SUB

SUB WinDrwMng (who)
GetStats who, text$, x, y, w, h, state
WinDrw text$, x, y, w, h, state, 1, 1, 1
IF state <> 0 THEN CtlDrawAll who
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

SUB WinPutTop (who)
IF WOrder(1) <> who THEN
        WinMakeHighest who
        WinRect who, x1, y1, x2, y2
        RepaintChange x1, y1, x2, y2, x1, y1, x2, y2
END IF
END SUB

'The rectangle a window covers, both ends included (screen coordinates).
SUB WinRect (who, x1, y1, x2, y2)
GetStats who, crap$, x, y, w, h, state
x1 = x
y1 = y
x2 = x + w
y2 = y + h
END SUB

'Move a window and paint only what changed.
SUB WinMoveTo (who, nx, ny)
WinRect who, ox1, oy1, ox2, oy2
dx = nx - WGData(who, 1)
dy = ny - WGData(who, 2)
IF dx = 0 AND dy = 0 THEN EXIT SUB
WGData(who, 1) = nx
WGData(who, 2) = ny
WinRect who, nx1, ny1, nx2, ny2

'The window in front shows all of itself, so its pixels can be copied. Only the
'part that is on the screen before and after can be.
IF WOrder(1) = who AND ClipActive = 0 THEN
        sx1 = ox1
        IF sx1 < 0 THEN sx1 = 0
        IF sx1 + dx < 0 THEN sx1 = -dx
        sx2 = ox2
        IF sx2 > 639 THEN sx2 = 639
        IF sx2 + dx > 639 THEN sx2 = 639 - dx
        sy1 = oy1
        IF sy1 < 0 THEN sy1 = 0
        IF sy1 + dy < 0 THEN sy1 = -dy
        sy2 = oy2
        IF sy2 > 479 THEN sy2 = 479
        IF sy2 + dy > 479 THEN sy2 = 479 - dy
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

'Resize a window and paint only what changed.
SUB WinSizeTo (who, nw, nh)
WinRect who, ox1, oy1, ox2, oy2
oldst = WGData(who, 5)
FOR i = 1 TO CtlCount
        IF Ctl(i).win = who THEN VisOld(i) = CtlVisible(i)
NEXT
WGData(who, 3) = nw
WGData(who, 4) = nh
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
FOR i = 1 TO CtlCount
        IF Ctl(i).win = who THEN
                IF VisOld(i) <> CtlVisible(i) THEN
                        CtlRect i, cx1, cy1, cx2, cy2
                        RepaintRect cx1, cy1, cx2, cy2
                END IF
        END IF
NEXT
mouse.show
END SUB

'Set the window state (0 rolled up, 1 normal, 2 maximised) and paint only what changed.
SUB WinSetState (who, st)
WinRect who, ox1, oy1, ox2, oy2
oldst = WGData(who, 5)
WGData(who, 5) = st
WinRect who, nx1, ny1, nx2, ny2
IF oldst <> 2 AND st <> 2 THEN
        'rolled up or normal before and after: same position and width, same
        'title bar. Only the part below it changes.
        IF oy2 > ny2 THEN ny2 = oy2
        mouse.hide
        WaitRetrace
        RepaintRect nx1, ny1 + TtlHeight + 1, nx2, ny2
        mouse.show
ELSE
        RepaintChange ox1, oy1, ox2, oy2, nx1, ny1, nx2, ny2
END IF
END SUB

'Paint the area the old rectangle covered, then the part of the new rectangle
'outside it. Every pixel is written once. The area they share is painted as part
'of the old rectangle.
SUB RepaintChange (ox1, oy1, ox2, oy2, nx1, ny1, nx2, ny2)
mouse.hide
WaitRetrace
RepaintRect ox1, oy1, ox2, oy2
'new minus old: a band above, a band below, then left and right of the overlap
IF nx2 < ox1 OR nx1 > ox2 OR ny2 < oy1 OR ny1 > oy2 THEN
        RepaintRect nx1, ny1, nx2, ny2
ELSE
        IF ny1 < oy1 THEN RepaintRect nx1, ny1, nx2, oy1 - 1
        IF ny2 > oy2 THEN RepaintRect nx1, oy2 + 1, nx2, ny2
        top = ny1: IF oy1 > top THEN top = oy1
        bot = ny2: IF oy2 < bot THEN bot = oy2
        IF nx1 < ox1 THEN RepaintRect nx1, top, ox1 - 1, bot
        IF nx2 > ox2 THEN RepaintRect ox2 + 1, top, nx2, bot
END IF
mouse.show
END SUB

'Paint a screen rectangle, both ends included, from the front window to the back.
'Each window is drawn through a clip (VIEW SCREEN) on the part of the rectangle
'that is still free, then that part is taken off the list. What is left at the
'end is background. No pixel is written twice, so nothing is erased and redrawn.
SUB RepaintRect (px1, py1, px2, py2)
rx1 = px1: ry1 = py1: rx2 = px2: ry2 = py2
IF rx1 < 0 THEN rx1 = 0
IF ry1 < 0 THEN ry1 = 0
IF rx2 > 639 THEN rx2 = 639
IF ry2 > 479 THEN ry2 = 479
IF rx1 > rx2 OR ry1 > ry2 THEN EXIT SUB

n = 1
FreeRX1(1) = rx1: FreeRY1(1) = ry1: FreeRX2(1) = rx2: FreeRY2(1) = ry2

FOR Cyc = 1 TO WNumber
        IF n = 0 THEN EXIT FOR
        CW = WOrder(Cyc)
        WinRect CW, wx1, wy1, wx2, wy2
        m = 0
        FOR i = 1 TO n
                ix1 = FreeRX1(i): IF wx1 > ix1 THEN ix1 = wx1
                iy1 = FreeRY1(i): IF wy1 > iy1 THEN iy1 = wy1
                ix2 = FreeRX2(i): IF wx2 < ix2 THEN ix2 = wx2
                iy2 = FreeRY2(i): IF wy2 < iy2 THEN iy2 = wy2
                IF ix1 > ix2 OR iy1 > iy2 THEN
                        m = m + 1
                        NextRX1(m) = FreeRX1(i): NextRY1(m) = FreeRY1(i): NextRX2(m) = FreeRX2(i): NextRY2(m) = FreeRY2(i)
                ELSE
                        ClipOn ix1, iy1, ix2, iy2
                        WinDrwMng CW
                        ClipOff
                        IF FreeRY1(i) < iy1 THEN
                                m = m + 1
                                NextRX1(m) = FreeRX1(i): NextRY1(m) = FreeRY1(i): NextRX2(m) = FreeRX2(i): NextRY2(m) = iy1 - 1
                        END IF
                        IF iy2 < FreeRY2(i) THEN
                                m = m + 1
                                NextRX1(m) = FreeRX1(i): NextRY1(m) = iy2 + 1: NextRX2(m) = FreeRX2(i): NextRY2(m) = FreeRY2(i)
                        END IF
                        IF FreeRX1(i) < ix1 THEN
                                m = m + 1
                                NextRX1(m) = FreeRX1(i): NextRY1(m) = iy1: NextRX2(m) = ix1 - 1: NextRY2(m) = iy2
                        END IF
                        IF ix2 < FreeRX2(i) THEN
                                m = m + 1
                                NextRX1(m) = ix2 + 1: NextRY1(m) = iy1: NextRX2(m) = FreeRX2(i): NextRY2(m) = iy2
                        END IF
                END IF
        NEXT
        n = m
        FOR i = 1 TO n
                FreeRX1(i) = NextRX1(i): FreeRY1(i) = NextRY1(i): FreeRX2(i) = NextRX2(i): FreeRY2(i) = NextRY2(i)
        NEXT
NEXT

FOR i = 1 TO n
        gFill FreeRX1(i), FreeRY1(i), FreeRX2(i), FreeRY2(i), 4
NEXT
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
        GET (ClipColX, py1)-(ClipColX, py2), ClipColBuf
        ClipCol = 1
END IF
IF py1 <> y1 OR py2 <> y2 THEN
        IF py1 <> y1 THEN ClipRowY = py1 ELSE ClipRowY = py2
        ClipRowX = x1
        GET (x1, ClipRowY)-(x2, ClipRowY), ClipRowBuf
        ClipRow = 1
END IF
ClipLX1 = px1: ClipLY1 = py1: ClipLX2 = px2: ClipLY2 = py2
ClipActive = -1
gView px1, py1, px2, py2
END SUB

SUB ClipOff
ClipActive = 0
gViewOff
IF ClipCol THEN PUT (ClipColX, ClipColY), ClipColBuf, PSET
IF ClipRow THEN PUT (ClipRowX, ClipRowY), ClipRowBuf, PSET
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

'-1 when a rectangle (or the bounding box of a line) lies completely outside the
'clip, or outside the screen when no clip is set. The drawing layer skips such
'calls: QBasic's LINE leaves a stray pixel in the bottom left corner of the view
'for a box that is entirely below and left of it.
FUNCTION Outside (x1, y1, x2, y2)
IF ClipActive THEN
        l = ClipLX1: t = ClipLY1: r = ClipLX2: b = ClipLY2
ELSE
        l = 0: t = 0: r = 639: b = 479
END IF
xl = x1: xh = x2
IF xl > xh THEN xl = x2: xh = x1
yl = y1: yh = y2
IF yl > yh THEN yl = y2: yh = y1
Outside = (xh < l OR xl > r OR yh < t OR yl > b)
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

SUB gCircle (x, y, r, c)
IF Outside(x - r, y - r, x + r, y + r) THEN EXIT SUB
CIRCLE (x, y), r, c
END SUB

'One glyph: its runs of set pixels, from the top row gy. Inside the clip the
'runs go straight to LINE; at the edge each is tested first.
SUB gGlyph (gx, gy, num, colo, st)
IF st >= 0 AND num >= 32 AND num <= 127 THEN
        IF ClipActive THEN
                inside = gx >= ClipLX1 AND gx + 7 <= ClipLX2 AND gy >= ClipLY1 AND gy + 15 <= ClipLY2
        ELSE
                inside = gx >= 0 AND gx + 7 <= 639 AND gy >= 0 AND gy + 15 <= 479
        END IF
        IF inside THEN
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
        IF inside THEN
                LINE (x0, ry)-(x1, ry), colo
        ELSEIF NOT Outside(x0, ry, x1, ry) THEN
                LINE (x0, ry)-(x1, ry), colo
        END IF
NEXT
END SUB

SUB gGetSprite (so)
GET (0, 0)-(7, 15), SprData(so)
END SUB

SUB gGet (x1, y1, x2, y2)
GET (x1, y1)-(x2, y2), BlitBuf
END SUB

SUB gPut (x, y)
PUT (x, y), BlitBuf, PSET
END SUB
'@@GFX-END

'---------------------------------------------------------------------------
'Controls. A control belongs to a window and is drawn in its client area, after
'the frame, so it is repainted (and clipped) with the window. A control that
'does not fit inside the client area is not drawn and cannot be hit.
'Events are not callbacks: a click or an accepted text box sets CtlEvent to the
'control number, and the main loop reads it.
'---------------------------------------------------------------------------

'Add a control and return its number (0 when the table is full).
'x, y, w, h are relative to the top left of the client area.
FUNCTION CtlAdd (win, kind, x, y, w, h, cap$)
IF CtlCount >= CtlMax THEN
        CtlAdd = 0
        EXIT FUNCTION
END IF
CtlCount = CtlCount + 1
Ctl(CtlCount).kind = kind
Ctl(CtlCount).win = win
Ctl(CtlCount).x = x
Ctl(CtlCount).y = y
Ctl(CtlCount).w = w
Ctl(CtlCount).h = h
Ctl(CtlCount).chk = 0
Ctl(CtlCount).grp = 1
Ctl(CtlCount).cap = cap$
CtlAdd = CtlCount
END FUNCTION

'Remove all controls.
SUB CtlReset
CtlCount = 0
CtlFocus = 0
CtlDown = 0
CtlEvent = 0
END SUB

'The screen rectangle of a control, both ends included.
SUB CtlRect (id, x1, y1, x2, y2)
WinRect Ctl(id).win, wx1, wy1, wx2, wy2
x1 = wx1 + 3 + Ctl(id).x
y1 = wy1 + TtlHeight + 4 + Ctl(id).y
x2 = x1 + Ctl(id).w - 1
y2 = y1 + Ctl(id).h - 1
END SUB

'-1 when the control is drawn: its window is not rolled up and the whole
'control is inside the client area.
FUNCTION CtlVisible (id)
CtlVisible = 0
GetStats Ctl(id).win, crap$, x, y, w, h, state
IF state = 0 THEN EXIT FUNCTION
CtlRect id, x1, y1, x2, y2
IF x1 >= x + 3 AND y1 >= y + TtlHeight + 4 AND x2 <= x + w - 3 AND y2 <= y + h - 3 THEN CtlVisible = -1
END FUNCTION

SUB CtlDraw (id)
CtlRect id, x1, y1, x2, y2
w = Ctl(id).w
h = Ctl(id).h
cap$ = RTRIM$(Ctl(id).cap)
SELECT CASE Ctl(id).kind
CASE CtlLabel
        CoutBg = 15
        cout cap$, x1, y1 + (h - 16) \ 2 - 1, 0, w, 0
CASE CtlButton
        nudge = 0
        IF CtlDown = id THEN hi = 2: lo = 15: nudge = 1 ELSE hi = 15: lo = 2
        gFill x1 + 2, y1 + 2, x2 - 2, y2 - 2, 3
        gLine x1 + 1, y1 + 1, x2 - 2, y1 + 1, hi
        gLine x1 + 1, y1 + 2, x1 + 1, y2 - 2, hi
        gLine x1 + 1, y2 - 1, x2 - 1, y2 - 1, lo
        gLine x2 - 1, y1 + 1, x2 - 1, y2 - 2, lo
        gBox x1, y1, x2, y2, 1
        tw = LEN(cap$) * 8
        CoutBg = 3
        cout cap$, x1 + (w - tw) \ 2 + nudge, y1 + (h - 16) \ 2 - 1 + nudge, 0, w, 0
CASE CtlCheck
        bx = y1 + (h - 13) \ 2
        gBox x1, bx, x1 + 12, bx + 12, 1
        gFill x1 + 1, bx + 1, x1 + 11, bx + 11, 15
        IF Ctl(id).chk THEN
                gLine x1 + 3, bx + 3, x1 + 9, bx + 9, 0
                gLine x1 + 3, bx + 4, x1 + 8, bx + 9, 0
                gLine x1 + 9, bx + 3, x1 + 3, bx + 9, 0
                gLine x1 + 9, bx + 4, x1 + 4, bx + 9, 0
        END IF
        CoutBg = 15
        cout cap$, x1 + 20, y1 + (h - 16) \ 2 - 1, 0, w - 20, 0
CASE CtlRadio
        cx = x1 + 6
        cy = y1 + h \ 2
        gFill cx - 6, cy - 6, cx + 6, cy + 6, 15
        gCircle cx, cy, 6, 1
        IF Ctl(id).chk THEN gFill cx - 2, cy - 2, cx + 2, cy + 2, 0
        CoutBg = 15
        cout cap$, x1 + 20, y1 + (h - 16) \ 2 - 1, 0, w - 20, 0
CASE CtlText
        IF CtlFocus = id THEN bc = 7 ELSE bc = 1
        gBox x1, y1, x2, y2, bc
        gFill x1 + 1, y1 + 1, x2 - 1, y2 - 1, 15
        n = (w - 8) \ 8
        shown$ = cap$
        IF LEN(shown$) > n THEN shown$ = RIGHT$(shown$, n)
        CoutBg = 15
        cout shown$, x1 + 4, y1 + (h - 16) \ 2 - 1, 0, w - 8, 0
        IF CtlFocus = id THEN
                cx = x1 + 4 + LEN(shown$) * 8
                gLine cx, y1 + 3, cx, y2 - 3, 0
        END IF
END SELECT
CoutBg = -1
END SUB

'Draw the controls of one window, in the order they were added. A control
'outside the clip, or not entirely inside the client area, is not drawn.
SUB CtlDrawAll (who)
IF CtlCount = 0 THEN EXIT SUB
GetStats who, crap$, x, y, w, h, state
IF state = 0 THEN EXIT SUB
ox = x + 3
oy = y + TtlHeight + 4
FOR i = 1 TO CtlCount
        IF Ctl(i).win = who THEN
                x1 = ox + Ctl(i).x
                y1 = oy + Ctl(i).y
                x2 = x1 + Ctl(i).w - 1
                y2 = y1 + Ctl(i).h - 1
                IF x1 >= ox AND y1 >= oy AND x2 <= x + w - 3 AND y2 <= y + h - 3 THEN
                        IF NOT Outside(x1, y1, x2, y2) THEN CtlDraw i
                END IF
        END IF
NEXT
END SUB

'Repaint one control (and whatever covers part of it) after its state changed.
SUB CtlRedraw (id)
IF id < 1 OR id > CtlCount THEN EXIT SUB
IF NOT CtlVisible(id) THEN EXIT SUB
CtlRect id, x1, y1, x2, y2
'Is a window in front of this one over the control?
covered = 0
FOR Cyc = 1 TO WNumber
        CW = WOrder(Cyc)
        IF CW = Ctl(id).win THEN EXIT FOR
        WinRect CW, wx1, wy1, wx2, wy2
        IF NOT (wx2 < x1 OR wx1 > x2 OR wy2 < y1 OR wy1 > y2) THEN
                covered = -1
                EXIT FOR
        END IF
NEXT
IF covered THEN
        RepaintChange x1, y1, x2, y2, x1, y1, x2, y2
ELSE
        'Nothing in front: the client background, then the controls of this
        'window that touch the rectangle, in the order they were added.
        mouse.hide
        WaitRetrace
        ClipOn x1, y1, x2, y2
        gFill x1, y1, x2, y2, 15
        FOR i = 1 TO CtlCount
                IF Ctl(i).win = Ctl(id).win THEN
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
FOR i = CtlCount TO 1 STEP -1
        IF Ctl(i).win = who AND Ctl(i).kind <> CtlLabel THEN
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
SUB CtlSetFocus (id)
old = CtlFocus
IF old = id THEN EXIT SUB
CtlFocus = id
IF old > 0 THEN CtlRedraw old
IF id > 0 THEN CtlRedraw id
END SUB

'Select one radio button of its group.
SUB CtlSelect (id)
FOR i = 1 TO CtlCount
        IF i <> id AND Ctl(i).kind = CtlRadio AND Ctl(i).win = Ctl(id).win AND Ctl(i).grp = Ctl(id).grp THEN
                IF Ctl(i).chk <> 0 THEN
                        Ctl(i).chk = 0
                        CtlRedraw i
                END IF
        END IF
NEXT
IF Ctl(id).chk = 0 THEN
        Ctl(id).chk = 1
        CtlRedraw id
END IF
END SUB

'What a click on a control does, after the button went up on it.
SUB CtlActivate (id)
SELECT CASE Ctl(id).kind
CASE CtlButton
        CtlEvent = id
CASE CtlCheck
        IF Ctl(id).chk THEN Ctl(id).chk = 0 ELSE Ctl(id).chk = 1
        CtlRedraw id
        CtlEvent = id
CASE CtlRadio
        CtlSelect id
        CtlEvent = id
CASE CtlText
        CtlSetFocus id
END SELECT
END SUB

'Follow the mouse until the button goes up. A button looks pressed while the
'pointer is on it; the click counts when the button goes up on it.
SUB CtlTrack (id)
IF Ctl(id).kind = CtlButton THEN
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
        CtlDown = 0
        CtlRedraw id
        IF isin THEN CtlActivate id
ELSE
        DO: LOOP WHILE mouse.getbutton = LB
        CtlActivate id
END IF
END SUB

'A key for the focused text box. Printable keys are added (40 characters at
'most), Backspace removes one, Enter accepts (CtlEvent), Esc leaves the box.
'The caption is stored in a fixed string, so trailing spaces are not kept.
SUB CtlKey (k$)
id = CtlFocus
IF id = 0 OR LEN(k$) <> 1 THEN EXIT SUB
IF Ctl(id).kind <> CtlText THEN EXIT SUB
c = ASC(k$)
cur$ = RTRIM$(Ctl(id).cap)
SELECT CASE c
CASE 8
        IF LEN(cur$) > 0 THEN
                Ctl(id).cap = LEFT$(cur$, LEN(cur$) - 1)
                CtlRedraw id
        END IF
CASE 13
        CtlEvent = id
CASE 27
        CtlSetFocus 0
CASE IS >= 32
        IF LEN(cur$) < 40 THEN
                Ctl(id).cap = cur$ + k$
                CtlRedraw id
        END IF
END SELECT
END SUB

SUB CtlSetText (id, t$)
Ctl(id).cap = t$
CtlRedraw id
END SUB

FUNCTION CtlGetText$ (id)
CtlGetText$ = RTRIM$(Ctl(id).cap)
END FUNCTION

'Check or uncheck a checkbox or radio button. Use CtlSelect for a radio button
'that must exclude the others of its group.
SUB CtlSetChecked (id, v)
IF v <> 0 THEN Ctl(id).chk = 1 ELSE Ctl(id).chk = 0
CtlRedraw id
END SUB

FUNCTION CtlGetChecked (id)
IF Ctl(id).chk <> 0 THEN CtlGetChecked = -1 ELSE CtlGetChecked = 0
END FUNCTION
