'SNUGGLE OS ALPHA!
'Copyright 1999 Alexander Schrab
'Thanks to:
'UPA for help and ideas
'Mark K. Kim for the Vmouse routine (Couldn't have done it without you!!)


DECLARE FUNCTION CheckIfWinBtn% (who%)
DECLARE FUNCTION CheckIfWinBttn% (who%)
DECLARE SUB mouse.setgcr (data$)
DECLARE SUB refresh ()
DECLARE SUB StartXYDrag (what%, who%)
DECLARE FUNCTION CheckIfBorder% (what%, who%)
DECLARE SUB StartXDrag (who%)
DECLARE SUB WinPutTop (who%)
DECLARE FUNCTION CheckIfWinArea% (who%)
DECLARE FUNCTION CheckWinArea% (who%)
DECLARE SUB WinMakeHighest (num%)
DECLARE SUB WinUnDrw (who%)
DECLARE SUB StartDrag (who%)
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
DECLARE FUNCTION StringFind% (Strng$, start%, what$)
DECLARE SUB mouse.show ()
DECLARE SUB mouse.hide ()
DECLARE FUNCTION mouse.enable% ()
DECLARE FUNCTION mouse.getbutton% ()
DECLARE FUNCTION mouse.loadgcr$ (filename$)
DECLARE FUNCTION mouse.loadTCR$ (filename$)
DECLARE FUNCTION shift.getstate% ()
DECLARE SUB WinDrwBrd (x1%, y1%, x2%, y2%)
DECLARE SUB WinDrwTtl (x1%, y1%, x2%, y2%)
'***************
CONST LB = &H1      'constant for left button
CONST RB = &H2      'constant for right button
CONST CB = &H4      'constant for center button
CONST DC = &H8      'constant for double click (reserved for next release)
CONST shift = &H3
CONST CTRL = &H4
CONST ALT = &H8
'***************
CONST TtlHeight = 18
DIM SHARED font(100, 8, 16) AS INTEGER
DIM SHARED font2(155, 8, 16) AS INTEGER

DIM SHARED WNMax AS INTEGER
WNMax = 10
DIM SHARED WNumber AS INTEGER
DIM SHARED WGData(WNMax, 6) AS INTEGER
DIM SHARED WTData(WNMax) AS STRING
DIM SHARED WOrder(WNMax) AS INTEGER
DIM SHARED move AS STRING
move = mouse.loadgcr("move")
DIM SHARED pointer AS STRING
pointer = mouse.loadgcr("pointer")
DIM SHARED vertical AS STRING
vertical = mouse.loadgcr("vertical")
DIM SHARED horizont AS STRING
horizont = mouse.loadgcr("horizont")
DIM SHARED diagonal AS STRING
diagonal = mouse.loadgcr("diagonal")

DIM SHARED SnuggleFolder AS STRING
'SnuggleFolder = "c:\develop\qbasic\snuggle\"
'CHDIR (SnuggleFolder)

DEFINT A-Z
SCREEN 12
enabled% = mouse.enable
mouse.setgcr pointer
mouse.show
Init

NewWin "Alfa", 90, 90, 300, 70
NewWin "Beta", 100, 100, 300, 70
NewWin "Welcome to the future", 120, 120, 300, 100
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
                mouse.hide
                        WinUnDrw CW
                        IF WGData(CW, 5) <> 2 THEN WGData(CW, 5) = 2 ELSE WGData(CW, 5) = 1
                        WinDrwMng CW
                mouse.show
                CASE 3
                mouse.hide
                        WinUnDrw CW
                        IF WGData(CW, 5) <> 0 THEN WGData(CW, 5) = 0 ELSE WGData(CW, 5) = 1
                        WinDrwMng CW
                mouse.show
                CASE ELSE
                END SELECT
                EXIT FOR
        END IF
        IF CheckIfTitle(CW) THEN
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
        IF CheckIfWinArea(CW) THEN
                DO: LOOP WHILE mouse.getbutton = LB
                WinPutTop CW
                EXIT FOR
        END IF
NEXT
END IF
IF UCASE$(INKEY$) = "R" THEN refresh
LOOP UNTIL UCASE$(INKEY$) = "Q"

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

SUB cout (text$, sx, sy, colo, Lengh, break)
DIM charlengh AS INTEGER

charlengh = (Lengh - (Lengh MOD 8)) / 8
RowChar = 0
FOR Char = 1 TO LEN(text$)
        RowChar = RowChar + 1
        IF RowChar > charlengh THEN
        IF break = 1 THEN sy = sy + 16: RowChar = 1 ELSE GOTO stopthis
        END IF
        num = ASC(MID$(text$, Char, 1))

        FOR y = 1 TO 16
                FOR x = 1 TO 8
                        IF num > 100 THEN col = font2(num - 100, x, y) ELSE col = font(num, x, y)
                        IF col = 1 THEN PSET (sx + (x - 1) + (RowChar - 1) * 8, sy + y), colo
                NEXT
        NEXT
NEXT
stopthis:
END SUB

SUB CoutSetup
COLOR 1
OUT &H3C8, 1
OUT &H3C9, 0
OUT &H3C9, 0
OUT &H3C9, 0

FOR a = 15 TO 255
LOCATE 1, 1
PRINT CHR$(a)
FOR y = 0 TO 15
FOR x = 0 TO 7
pnt = POINT(x, y)
IF pnt <> 0 THEN pnt = 1
IF a <= 100 THEN
font(a, x + 1, y + 1) = pnt
ELSE
font2(a - 100, x + 1, y + 1) = pnt
END IF
NEXT
NEXT
NEXT

END SUB

SUB DrwBtn (x, y, w, h, up)
IF up = 1 THEN Col1 = 1: Col2 = 3 ELSE Col2 = 1: Col1 = 3

LINE (x, y)-(x + w, y + h), 2, BF
LINE (x, y)-(x, y + h - 1), Col2
LINE (x, y)-(x + h - 1, y), Col2
LINE (x + w, y + h)-(x + 1, y + h), Col1
LINE (x + w, y + h)-(x + w, y + 1), Col1

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

SUB Init
CoutSetup
OUT &H3C8, 0
OUT &H3C9, 0
OUT &H3C9, 0
OUT &H3C9, 0

OUT &H3C8, 1
OUT &H3C9, 22
OUT &H3C9, 22
OUT &H3C9, 22

OUT &H3C8, 2
OUT &H3C9, 32
OUT &H3C9, 32
OUT &H3C9, 32

OUT &H3C8, 3
OUT &H3C9, 42
OUT &H3C9, 42
OUT &H3C9, 42

OUT &H3C8, 4
OUT &H3C9, 0
OUT &H3C9, 40
OUT &H3C9, 40

OUT &H3C8, 5
OUT &H3C9, 0
OUT &H3C9, 0
OUT &H3C9, 22

OUT &H3C8, 6
OUT &H3C9, 0
OUT &H3C9, 0
OUT &H3C9, 32

OUT &H3C8, 7
OUT &H3C9, 0
OUT &H3C9, 0
OUT &H3C9, 42

END SUB

SUB MaxButton (x, y)
LINE (x + 2, y + 4)-(x + 10, y + 4), 1
LINE (x + 3, y + 3)-(x + 9, y + 3), 6
LINE (x + 2, y + 2)-(x + 10, y + 10), 1, B
LINE (x + 3, y + 5)-(x + 9, y + 9), 15, BF
END SUB

SUB MinButton (x, y)
LINE (x + 3, y + 6)-(x + 9, y + 6), 6
LINE (x + 2, y + 5)-(x + 10, y + 7), 1, B
END SUB

'Disable mouse.
'EXAMPLE:
'  enabled% = mouse.enable  'enable mouse
'  mouse.show               'show mouse
'  a$ = INPUT$(1)           'pause
'  mouse.disable            'disable mouse
SUB mouse.disable
  SHARED mouse.exist AS INTEGER
  IF mouse.exist THEN
    mouse.hide
    mouse.exist = 0
  END IF
END SUB

'Enable mouse for usage. Must be run before any mouse functions (other than
'cursor-loading functions) or none will work.
'RETURN:
'  -1 (&hFFFF) if mouse found, else 0.
'EXAMPLE:
'  IF NOT mouse.enable THEN PRINT "No mouse" ELSE PRINT "Mouse found"
FUNCTION mouse.enable%
  SHARED mouse.exist AS INTEGER

  'store machine language data
  SHARED mouse.asm$
  mouse.asm$ = ""
  mouse.asm$ = mouse.asm$ + CHR$(&H55)                            'push bp
  mouse.asm$ = mouse.asm$ + CHR$(&H89) + CHR$(&HE5)               'mov  bp, sp
  mouse.asm$ = mouse.asm$ + CHR$(&H8B) + CHR$(&H5E) + CHR$(&HE)   'mov  bx, [bp+0e]
  mouse.asm$ = mouse.asm$ + CHR$(&H8B) + CHR$(&H7)                'mov  ax, [bx]
  mouse.asm$ = mouse.asm$ + CHR$(&H50)                            'push ax
  mouse.asm$ = mouse.asm$ + CHR$(&H8B) + CHR$(&H5E) + CHR$(&HC)   'mov  bx, [bp+0c]
  mouse.asm$ = mouse.asm$ + CHR$(&H8B) + CHR$(&H7)                'mov  cx, [ax]
  mouse.asm$ = mouse.asm$ + CHR$(&H50)                            'push ax
  mouse.asm$ = mouse.asm$ + CHR$(&H8B) + CHR$(&H5E) + CHR$(&HA)   'mov  bx, [bp+0a]
  mouse.asm$ = mouse.asm$ + CHR$(&H8B) + CHR$(&HF)                'mov  cx, [bx]
  mouse.asm$ = mouse.asm$ + CHR$(&H8B) + CHR$(&H5E) + CHR$(&H8)   'mov  bx, [bp+08]
  mouse.asm$ = mouse.asm$ + CHR$(&H8B) + CHR$(&H17)               'mov  dx, [bx]
'  mouse.asm$ = mouse.asm$ + CHR$(&H1E)                            'push ds
'  mouse.asm$ = mouse.asm$ + CHR$(&H7)                             'pop  es
  mouse.asm$ = mouse.asm$ + CHR$(&H8B) + CHR$(&H5E) + CHR$(&H6)   'mov  bx, [bp+06]
  mouse.asm$ = mouse.asm$ + CHR$(&H8E) + CHR$(&H7)                'mov  es, [bx]
  mouse.asm$ = mouse.asm$ + CHR$(&H5B)                            'pop  bx
  mouse.asm$ = mouse.asm$ + CHR$(&H58)                            'pop  ax
  mouse.asm$ = mouse.asm$ + CHR$(&HCD) + CHR$(&H33)               'int  33h
  mouse.asm$ = mouse.asm$ + CHR$(&H53)                            'push bx
  mouse.asm$ = mouse.asm$ + CHR$(&H8B) + CHR$(&H5E) + CHR$(&HE)   'mov  bx, [bp+0e]
  mouse.asm$ = mouse.asm$ + CHR$(&H89) + CHR$(&H7)                'mov  [bx], ax
  mouse.asm$ = mouse.asm$ + CHR$(&H58)                            'pop  ax
  mouse.asm$ = mouse.asm$ + CHR$(&H8B) + CHR$(&H5E) + CHR$(&HC)   'mov  bx, [bp+0c]
  mouse.asm$ = mouse.asm$ + CHR$(&H89) + CHR$(&H7)                'mov  [bx], ax
  mouse.asm$ = mouse.asm$ + CHR$(&H8B) + CHR$(&H5E) + CHR$(&HA)   'mov  bx, [bp+0a]
  mouse.asm$ = mouse.asm$ + CHR$(&H89) + CHR$(&HF)                'mov  [bx], cx
  mouse.asm$ = mouse.asm$ + CHR$(&H8B) + CHR$(&H5E) + CHR$(&H8)   'mov  bx, [bp+08]
  mouse.asm$ = mouse.asm$ + CHR$(&H89) + CHR$(&H17)               'mov  [bx], dx
  mouse.asm$ = mouse.asm$ + CHR$(&H5D)                            'pop  bp
  mouse.asm$ = mouse.asm$ + CHR$(&HCA) + CHR$(&H12) + CHR$(&H0)   'retf 12

  'initialize and check mouse existance
  mouse.asmseg% = VARSEG(mouse.asm$)
  mouse.asmoff% = SADD(mouse.asm$)
  ax% = 0
  DEF SEG = mouse.asmseg%
  CALL absolute(dummy%, dummy%, dummy%, dummy%, ax%, 0, 0, 0, 0, mouse.asmoff%)
  DEF SEG
  mouse.exist = ax%

  mouse.enable = mouse.exist
END FUNCTION

'Gets mouse status (coordinates and button status.)
'COMMENT:
'* Coordinates are in pixels, even if the screen is in text mode.
'INPUT:
'* x% = integer variable to store x coordinate
'* y% = integer variable to store y coordinate
'* buttons% = integer variable to store buttons status where:
'  * buttons% becomes LB if left button is pressed
'  * buttons% becomes RB if right button is pressed
'  * buttons% becomes CB if center buttons is pressed
'  * or combination (left button and right button makes buttons% = LB + RB)
'    including double clicks (ie - LB + DC).
'* LB, RB, and CB are mouse constants found in the main module.
'EXAMPLE:
'  CLS
'  enabled% = mouse.enable
'  mouse.show
'  DO
'    mouse.get x%, y%, buttons%
'    LOCATE 1, 1: PRINT USING "####  ####  ####"; x%; y%; buttons%
'  LOOP WHILE INKEY$ = ""
'  mouse.disable
SUB mouse.get (x%, y%, buttons%)
  SHARED mouse.exist AS INTEGER
  SHARED mouse.asm$
  mouse.asmseg% = VARSEG(mouse.asm$)
  mouse.asmoff% = SADD(mouse.asm$)
  IF mouse.exist THEN
    DEF SEG = mouse.asmseg%
    CALL absolute(dummy%, dummy%, dummy%, dummy%, &H3, bx%, x%, y%, 0, mouse.asmoff%)
    DEF SEG
  END IF
  buttons% = 0
  IF bx% AND &H1 THEN buttons% = buttons% OR LB
  IF bx% AND &H2 THEN buttons% = buttons% OR RB
  IF bx% AND &H4 THEN buttons% = buttons% OR CB
END SUB

'Gets the status of mouse buttons.
'COMMENT:
'* Using mouse.get() function is recommended instead when using both
'  mouse.getbutton() and mouse.getpos() functions.
'RETURN:
'* An integer value:
'  * LB for Left Button
'  * RB for Right Button
'  * CB for Center Button (if any)
'  * or combination (left button and right button makes buttons% = LB + RB)
'    including double clicks (ie - LB + DC).
'* LB, RB, and CB are mouse constants found in the main module.
'EXAMPLE:
'  CLS
'  enabled% = mouse.enable
'  mouse.show
'  DO
'    buttons% = mouse.getbutton
'    LOCATE 1, 1: PRINT USING "####"; buttons%
'  LOOP WHILE INKEY$ = ""
'  mouse.disable
FUNCTION mouse.getbutton%
  SHARED mouse.exist AS INTEGER
  SHARED mouse.asm$
  mouse.asmseg% = VARSEG(mouse.asm$)
  mouse.asmoff% = SADD(mouse.asm$)
  IF mouse.exist THEN
    DEF SEG = mouse.asmseg%
    CALL absolute(dummy%, dummy%, dummy%, dummy%, &H3, bx%, 0, 0, 0, mouse.asmoff%)
   
    DEF SEG
  END IF
  ret% = 0
 
  IF bx% AND &H1 THEN ret% = ret% OR LB
  IF bx% AND &H2 THEN ret% = ret% OR RB
  IF bx% AND &H4 THEN ret% = ret% OR CB
  mouse.getbutton% = ret%
END FUNCTION

'Gets the last coordinate where a mouse button was pressed
'COMMENT:
'* Coordinates are in pixels, even if the screen is in text mode.
'INPUT:
'* mouse.constant% is a mouse constant of LB (left button), RB (right
'  button), or CB (center button) for button press check. No combination
'  allowed. Any values other than LB, RB, and CB will default to LB.
'* x% and y% are the variables to store x and y corrdinates where the mouse
'  button was pressed.
'EXAMPLE:
'  CLS
'  enabled% = mouse.enable
'  mouse.show
'  DO
'    mouse.getlastdown LB, x%, y%
'    LOCATE 1, 1: PRINT USING "####  ####"; x%; y%
'  LOOP WHILE INKEY$ = ""
'  mouse.disable
SUB mouse.getlastdown (mouse.constant%, x%, y%)
  SHARED mouse.exist AS INTEGER
  SHARED mouse.asm$
  mouse.asmseg% = VARSEG(mouse.asm$)
  mouse.asmoff% = SADD(mouse.asm$)
  IF mouse.exist THEN
    SELECT CASE mouse.constant%
      CASE LB: Button% = 0
      CASE RB: Button% = 1
      CASE CB: Button% = 2
      CASE ELSE: Button% = 0
    END SELECT
    DEF SEG = mouse.asmseg%
    CALL absolute(dummy%, dummy%, dummy%, dummy%, &H5, Button%, cx%, dx%, 0, mouse.asmoff%)
    DEF SEG
    x% = cx%
    y% = dx%
  END IF
END SUB

'Gets the last coordinate where a mouse button was released
'COMMENT:
'* Coordinates are in pixels, even if the screen is in text mode.
'INPUT:
'* mouse.constant% is a mouse constant of LB (left button), RB (right
'  button), or CB (center button) for button release check. No combination
'  allowed.
'* x% and y% are the variables to store x and y corrdinates where the mouse
'  button was released.
'EXAMPLE:
'  CLS
'  enabled% = mouse.enable
'  mouse.show
'  DO
'    mouse.getlastup LB, x%, y%
'    LOCATE 1, 1: PRINT USING "####  ####"; x%; y%
'  LOOP WHILE INKEY$ = ""
'  mouse.disable
SUB mouse.getlastup (mouse.constant%, x%, y%)
  SHARED mouse.exist AS INTEGER
  SHARED mouse.asm$
  mouse.asmseg% = VARSEG(mouse.asm$)
  mouse.asmoff% = SADD(mouse.asm$)
  IF mouse.exist THEN
    SELECT CASE mouse.constant%
      CASE LB: Button% = 0
      CASE RB: Button% = 1
      CASE CB: Button% = 2
      CASE ELSE: Button% = 0
    END SELECT
    DEF SEG = mouse.asmseg%
    CALL absolute(dummy%, dummy%, dummy%, dummy%, &H6, Button%, cx%, dx%, 0, mouse.asmoff%)
    DEF SEG
    x% = cx%
    y% = dx%
  END IF
END SUB

'Gets the movement of the mouse since last call
'COMMENT:
'* Coordinates are in pixels, even if the screen is in text mode.
'INPUT:
'* x% and y% are variables to store the horizontal and vertical movements,
'  respectively.
'* Right and Down are positives, Left and Up are negatives
'EXAMPLE:
'  CLS
'  enabled% = mouse.enable
'  mouse.show
'  DO
'    mouse.getmovement x%, y%
'    LOCATE 1, 1: PRINT USING "####  ####"; x%; y%
'    SLEEP 1
'  LOOP WHILE INKEY$ = ""
'  mouse.disable
SUB mouse.getmovement (x%, y%)
  SHARED mouse.exist AS INTEGER
  SHARED mouse.asm$
  mouse.asmseg% = VARSEG(mouse.asm$)
  mouse.asmoff% = SADD(mouse.asm$)
  IF mouse.exist THEN
    DEF SEG = mouse.asmseg%
    CALL absolute(dummy%, dummy%, dummy%, dummy%, &HB, 0, cx%, dx%, 0, mouse.asmoff%)
    DEF SEG
    x% = cx%
    y% = dx%
  END IF
END SUB

'Gets mouse coordinates.
'COMMENT:
'* Coordinates are in pixels, even if the screen is in text mode.
'COMMENT:
'* Using mouse.get() function is recommended instead when using both
'  mouse.getpos() and mouse.getbutton() functions.
'INPUT:
'* x% = integer variable to store x coordinate
'* y% = integer variable to store y coordinate
'EXAMPLE:
'  CLS
'  enabled% = mouse.enable
'  mouse.show
'  DO
'    mouse.getpos x%, y%
'    LOCATE 1, 1: PRINT USING "####  ####"; x%; y%
'  LOOP WHILE INKEY$ = ""
'  mouse.disable
SUB mouse.getpos (x%, y%)
  SHARED mouse.exist AS INTEGER
  SHARED mouse.asm$
  mouse.asmseg% = VARSEG(mouse.asm$)
  mouse.asmoff% = SADD(mouse.asm$)
  IF mouse.exist THEN
    DEF SEG = mouse.asmseg%
    CALL absolute(dummy%, dummy%, dummy%, dummy%, &H3, 0, x%, y%, 0, mouse.asmoff%)
    DEF SEG
  END IF
END SUB

'Hides mouse cursor
'EXAMPLE:
'  enabled% = mouse.enable  'enable mouse
'  mouse.show               'show mouse
'  a$ = INPUT$(1)           'pause
'  mouse.hide               'hide mouse
'  a$ = INPUT$(1)           'pause
'  mouse.disable            'disable mouse
SUB mouse.hide
  SHARED mouse.exist AS INTEGER
  SHARED mouse.asm$
  mouse.asmseg% = VARSEG(mouse.asm$)
  mouse.asmoff% = SADD(mouse.asm$)
  SHARED mouse.visible AS INTEGER
  IF mouse.exist AND mouse.visible THEN
    DEF SEG = mouse.asmseg%
    CALL absolute(dummy%, dummy%, dummy%, dummy%, &H2, 0, 0, 0, 0, mouse.asmoff%)
    DEF SEG
    mouse.visible = 0
  END IF
END SUB

'Loads the graphics cursor
'COMMENT:
'* Requies MS Mouse driver version 3.0 or compatible
'INPUT:
'* filename$ is the file name to input the graphics cursor's data from.
'* If filename$ has no extention, it defaults to .GCR (Graphics CuRsor)
'  extention.
'RETURN:
'* Returns the graphics cursor data in the string form.
'EXAMPLE:
'  SCREEN 9   'requires EGA or better
'  enabled% = mouse.enable
'  mouse.show
'  data$ = mouse.loadGCR$("cursor.gcr")
'  mouse.setGCR data$
FUNCTION mouse.loadgcr$ (filename$)
  IF INSTR(filename$, ".") = 0 THEN filename$ = filename$ + ".GCR"

  filenumber% = FREEFILE
  OPEN filename$ FOR BINARY AS filenumber%
    strn$ = SPACE$(3)
    GET #filenumber%, 1, strn$
    IF strn$ = "GCR" THEN
      strn$ = SPACE$(69)
      GET #filenumber%, 1, strn$
    ELSE strn$ = ""
    END IF
  CLOSE filenumber%
  mouse.loadgcr$ = strn$
END FUNCTION

'Loads the text cursor
'COMMENT:
'* Requies MS Mouse driver version 3.0 or compatible
'INPUT:
'* filename$ is the file name to input the graphics cursor's data from.
'* If filename$ has no extention, it defaults to .TCR (Text CuRsor) extention.
'RETURN:
'* Returns the text cursor data in the string form.
'EXAMPLE:
'  enabled% = mouse.enable
'  mouse.show
'  data$ = mouse.loadTCR$("cursor.tcr")
'  mouse.setTCR data$
FUNCTION mouse.loadTCR$ (filename$)
  IF INSTR(filename$, ".") = 0 THEN filename$ = filename$ + ".TCR"
 
  filenumber% = FREEFILE
  OPEN filename$ FOR BINARY AS filenumber%
    strn$ = SPACE$(3)
    GET #filenumber%, 1, strn$
    IF strn$ = "TCR" THEN
      strn$ = SPACE$(8)
      GET #filenumber%, 1, strn$
    ELSE strn$ = ""
    END IF
  CLOSE filenumber%
  mouse.loadTCR$ = strn$
END FUNCTION

'Changes the graphics cursor
'COMMENT:
'* Requies MS Mouse driver version 3.0 or compatible
'INPUT:
'* data$ is the graphics cursor data gotten from a file using the function
'  mouse.loadGCR().
'EXAMPLE:
'  SCREEN 9   'requires EGA or better
'  enabled% = mouse.enable
'  mouse.show
'  data$ = mouse.loadGCR$("cursor.gcr")
'  mouse.setGCR data$
SUB mouse.setgcr (data$)
  SHARED mouse.exist AS INTEGER
  SHARED mouse.asm$
  mouse.asmseg% = VARSEG(mouse.asm$)
  mouse.asmoff% = SADD(mouse.asm$)
  IF mouse.exist AND LEN(data$) = 69 AND LEFT$(data$, 3) = "GCR" THEN
    'get hotx value
    hotxstr$ = MID$(data$, 68, 1)
    DEF SEG = VARSEG(hotxstr$)
    bx% = PEEK(SADD(hotxstr$))
    DEF SEG
    'get hoty value
    hotystr$ = MID$(data$, 69, 1)
    DEF SEG = VARSEG(hotystr$)
    cx% = PEEK(SADD(hotystr$))
    DEF SEG
    'get image shape values
    dx% = SADD(data$) + 3
    es% = VARSEG(data$)
    'execute
    DEF SEG = mouse.asmseg%
    CALL absolute(dummy%, dummy%, dummy%, dummy%, &H9, bx%, cx%, dx%, es%, mouse.asmoff%)
    DEF SEG
  END IF
END SUB

'Sets a "boxed" area for the mouse to move around. It cannot go beyond.
'COMMENT:
'* Coordinates are in pixels, even if the screen is in text mode.
'INPUT:
'* (x1%, y1%) is the top-left coordinate of the box.
'* (x2%, y2%) is the bottom-right coordinate of the box.
'EXAMPLE:
'  enabled% = mouse.enable
'  mouse.show
'  mouse.setlimit 50, 50, 300, 100
'  a$ = INPUT$(1)  'wait for a key
'  mouse.disable
SUB mouse.setlimit (x1%, y1%, x2%, y2%)
  SHARED mouse.exist AS INTEGER
  SHARED mouse.asm$
  mouse.asmseg% = VARSEG(mouse.asm$)
  mouse.asmoff% = SADD(mouse.asm$)
  IF mouse.exist THEN
    cx% = x1%
    dx% = x2%
    DEF SEG = mouse.asmseg%
    CALL absolute(dummy%, dummy%, dummy%, dummy%, &H7, 0, cx%, dx%, 0, mouse.asmoff%)
    DEF SEG
    cx% = y1%
    dx% = y2%
    DEF SEG = mouse.asmseg%
    CALL absolute(dummy%, dummy%, dummy%, dummy%, &H8, 0, cx%, dx%, 0, mouse.asmoff%)
    DEF SEG
  END IF
END SUB

'Moves the mouse position to (x%, y%)
'COMMENT:
'* Coordinates are in pixels, even if the screen is in text mode.
'NOTES:
'* The inputted values, x% and y%, must be in "pixels", not in "blocks", even
'  in text mode.
'EXAMPLE:
'  enabled% = mouse.enable
'  mouse.show
'  DO
'    mouse.setpos 100, 100
'    SLEEP 1
'  LOOP WHILE INKEY$ = ""
'  mouse.disable
SUB mouse.setpos (x%, y%)
  SHARED mouse.exist AS INTEGER
  SHARED mouse.asm$
  mouse.asmseg% = VARSEG(mouse.asm$)
  mouse.asmoff% = SADD(mouse.asm$)
  IF mouse.exist THEN
    cx% = x%
    dx% = y%
    DEF SEG = mouse.asmseg%
    CALL absolute(dummy%, dummy%, dummy%, dummy%, &H4, 0, cx%, dx%, 0, mouse.asmoff%)
    DEF SEG
  END IF
END SUB

'Changes the mouse speed
'COMMENT:
'* This interrupt service actually sets the ratio between mickey (the small-
'  est movement the mouse can detect) and the pixels.  This function does
'  some calculations to make it simulate a speed setting interrupt service.
'   There is aactually a speed setting interrupt service, but it is available
'  to MS Mouse Driver version 6.0 and compatibles so I didn't want to do
'  that.  All the functions in this QBASIC functions are MS Mouse Driver ver-
'  sion 1.0 and compatible with the exception of graphics cursor setting
'  functions and text cursor setting functions.
'INPUT:
'* x% is the new horizontal mouse speed
'* y% is the new vertical mouse speed
'* The minimum value is -32,768 (go backwards) and the maximum value is
'  32,767, same as the minimum and the maximum value limit of integers.
'EXAMPLE:
'  enabled% = mouse.enable
'  mouse.show
'  mouse.setspeed &H7FFF, &H7FFF
'  a$ = INPUT$(1)  'wait for a key
'  mouse.disable
SUB mouse.setspeed (x%, y%)
  SHARED mouse.exist AS INTEGER
  SHARED mouse.asm$
  mouse.asmseg% = VARSEG(mouse.asm$)
  mouse.asmoff% = SADD(mouse.asm$)
  IF mouse.exist THEN
    DEF SEG = mouse.asmseg%
    CALL absolute(dummy%, dummy%, dummy%, dummy%, &HF, 0, (x% XOR &H7FFF), (y% XOR &H7FFF), 0, mouse.asmoff%)
    DEF SEG
  END IF
END SUB

'Changes the text cursor
'COMMENT:
'* Requies MS Mouse driver version 3.0 or compatible
'INPUT:
'* data$ is the text cursor data gotten from a file using the function
'  mouse.loadTCR().
'EXAMPLE:
'  enabled% = mouse.enable
'  mouse.show
'  data$ = mouse.loadTCR$("cursor.tcr")
'  mouse.setTCR data$
SUB mouse.setTCR (data$)
  SHARED mouse.exist AS INTEGER
  SHARED mouse.asm$
 
  IF NOT (mouse.exist AND LEN(data$) = 8 AND LEFT$(data$, 3) = "TCR") THEN EXIT SUB
 
  'get cursor type value
  cursortype$ = MID$(data$, 4, 1)
  DEF SEG = VARSEG(cursortype$)
  bx% = PEEK(SADD(cursortype$))
  DEF SEG
  'get arg1 value
  arg1h$ = MID$(data$, 5, 1)
  DEF SEG = VARSEG(arg1h$)
  argh% = PEEK(SADD(arg1h$))
  DEF SEG
  arg1l$ = MID$(data$, 6, 1)
  DEF SEG = VARSEG(arg1l$)
  argl% = PEEK(SADD(arg1l$))
  DEF SEG
  cx% = (argh% AND &H7F) * &H100 + argl%
   IF argh% AND &H80 THEN cx% = cx% OR &H8000
  'get arg2 value
  arg2h$ = MID$(data$, 7, 1)
  DEF SEG = VARSEG(arg2h$)
  argh% = PEEK(SADD(arg2h$))
  DEF SEG
  arg2l$ = MID$(data$, 8, 1)
  DEF SEG = VARSEG(arg2l$)
  argl% = PEEK(SADD(arg2l$))
  DEF SEG
  dx% = (argh% AND &H7F) * &H100 + argl%
   IF argh% AND &H80 THEN dx% = dx% OR &H8000
  'execute
  mouse.asmseg% = VARSEG(mouse.asm$)
  mouse.asmoff% = SADD(mouse.asm$)
  DEF SEG = mouse.asmseg%
  CALL absolute(dummy%, dummy%, dummy%, dummy%, &HA, bx%, cx%, dx%, 0, mouse.asmoff%)
  DEF SEG
END SUB

'Shows the mouse. Must have been enabled first.
'EXAMPLE:
'  enabled% = mouse.enable  'enable mouse
'  mouse.show               'show mouse
'  a$ = INPUT$(1)           'pause
'  mouse.disable            'disable mouse
SUB mouse.show
  SHARED mouse.exist AS INTEGER
  SHARED mouse.asm$
  mouse.asmseg% = VARSEG(mouse.asm$)
  mouse.asmoff% = SADD(mouse.asm$)
  SHARED mouse.visible AS INTEGER
  IF mouse.exist AND NOT mouse.visible THEN
    DEF SEG = mouse.asmseg%
    CALL absolute(dummy%, dummy%, dummy%, dummy%, &H1, 0, 0, 0, 0, mouse.asmoff%)
    DEF SEG
    mouse.visible = 1
  END IF
END SUB

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
LINE (x + 5, y + 2)-(x + 7, y + 6), 1, B
LINE (x + 5, y + 8)-(x + 7, y + 10), 1, B
LINE (x + 6, y + 3)-(x + 6, y + 5), 6
PSET (x + 6, y + 9), 6


END SUB

SUB refresh
mouse.hide
CLS
LINE (0, 0)-(640, 480), 4, BF
FOR Cyc = WNumber TO 1 STEP -1
CW = WOrder(Cyc)
WinDrwMng CW
NEXT
mouse.show
END SUB

'Gets shift state.
'RETURN:
'* 0 if no shift key pressed
'* ALT if Alt key pressed
'* CTRL if Ctrl key pressed
'* SHIFT if Shift key pressed
'* These may be in combination.  For example, if Ctrl-Alt is pressed, then
'  return is CTRL + ALT.
'* ALT, CTRL, and SHIFT are shift constants defined in the main module.
'EXAMPLE:
'  CLS
'  enabled% = mouse.enable
'  mouse.show
'  DO
'    mouse.get x%, y%, buttons%
'    shiftstate% = shift.getstate%
'    IF buttons% THEN
'      LOCATE 1, 1: PRINT SPACE$(79); : LOCATE 1, 1
'      SELECT CASE shiftstate%
'        CASE 0: PRINT "Mouse button was pressed without any shift keys."
'        CASE ALT: PRINT "Mouse button and Alt key pressed."
'        CASE CTRL: PRINT "Mouse button and Ctrl key pressed."
'        CASE SHIFT: PRINT "Mouse button and Shift key pressed."
'      END SELECT
'    END IF
'  LOOP WHILE INKEY$ = ""
FUNCTION shift.getstate%
  DEF SEG = 0
  state% = PEEK(&H417) AND &HF
  DEF SEG
  IF (state% AND &H3) THEN state% = (state% OR &H3)
  shift.getstate% = state%
END FUNCTION

SUB StartDrag (who)
mouse.setgcr move
mouse.getpos ox, oy
        x = ox: y = oy
        GetStats who, crap$, wx, wy, ww, wh, wstate
DO
        lx = x: ly = y
        mouse.getpos x, y
        IF lx = x AND ly = y THEN
        ELSE
        mouse.hide
        WinUnDrw (who)
                WGData(who, 1) = wx + (x - ox)
                WGData(who, 2) = wy + (y - oy)
        WinDrwMng (who)
        ELSE
        mouse.show
        END IF
LOOP UNTIL mouse.getbutton <> LB
mouse.hide
mouse.setgcr pointer
mouse.show
END SUB

SUB StartXYDrag (what, who)
mouse.hide
IF what = 1 THEN mouse.setgcr horizont
IF what = 2 THEN mouse.setgcr vertical
IF what = 3 THEN mouse.setgcr diagonal
mouse.getpos ox, oy
        x = ox: y = oy
        GetStats who, crap$, wx, wy, ww, wh, wstate
DO
        lx = x: ly = y
        mouse.getpos x, y
        IF lx = x AND ly = y THEN
        ELSE
        mouse.hide
        WinUnDrw (who)
        
        IF what <> 2 THEN WGData(who, 3) = ww + (x - ox)
        IF what <> 1 THEN WGData(who, 4) = wh + (y - oy)
        WinDrwMng (who)
        mouse.show
        END IF
LOOP UNTIL mouse.getbutton <> LB
mouse.hide
mouse.setgcr pointer
mouse.show

END SUB

FUNCTION StringFind (Strng$, start, what$)
FOR a = start TO LEN(Strng$) + 1
IF a <= LEN(Strng$) THEN
        IF MID$(Strng$, a, 1) = LTRIM$(RTRIM$(what$)) THEN
                EXIT FOR
        END IF
END IF
NEXT
StringFind = a
END FUNCTION

SUB WinDrw (text$, x, y, w, h, state, btnA, btnB, btnC)
       
        WinDrwTtl x, y, x + w, y + TtlHeight
                Lengh = w - TtlHeight * 3 - 2 - 5
                CharsVis = (Lengh - (Lenght MOD 8)) / 8
                print$ = MID$(text$, 1, CharsVis)
                IF LEN(text$) <> LEN(print$) AND LEN(print$) >= 3 THEN MID$(print$, LEN(print$) - 2, 3) = "..."
                cout print$, x + 5, y, 2, Lengh + 8, 0

                DrwBtn x + w - TtlHeight * 3, y + 3, TtlHeight - 6, TtlHeight - 6, btnA
                DrwBtn x + w - TtlHeight * 2, y + 3, TtlHeight - 6, TtlHeight - 6, btnB
                DrwBtn x + w - TtlHeight * 1, y + 3, TtlHeight - 6, TtlHeight - 6, btnC

                MinButton x + w - TtlHeight * 3, y + 3
                MaxButton x + w - TtlHeight * 2, y + 3
                QuitButton x + w - TtlHeight * 1, y + 3
        IF state <> 0 THEN WinDrwBrd x, y + TtlHeight + 1, x + w, y + h

       

END SUB

SUB WinDrwBrd (x1, y1, x2, y2)

LINE (x1, y1)-(x2, y2), 15, BF

LINE (x1, y1)-(x2, y2), 3, B
LINE (x1 + 1, y1 + 1)-(x2 - 1, y2 - 1), 2, B
LINE (x1 + 2, y1 + 2)-(x2 - 2, y2 - 2), 1, B

LINE (x2 - 2, y2 - 2)-(x2 - 2, y1 + 3), 3
LINE (x2 - 2, y2 - 2)-(x1 + 3, y2 - 2), 3

LINE (x2, y2)-(x2, y1 + 1), 1
LINE (x2, y2)-(x1 + 1, y2), 1

LINE (x2, y1)-(x2 - 2, y1 + 2), 2
LINE (x1, y2)-(x1 + 2, y2 - 2), 2


END SUB

SUB WinDrwMng (who)
GetStats who, text$, x, y, w, h, state
WinDrw text$, x, y, w, h, state, 1, 1, 1
END SUB

SUB WinDrwTtl (x1, y1, x2, y2)
LINE (x1, y1)-(x2, y2), 6, BF

LINE (x1, y1)-(x2 - 1, y1), 7
LINE (x1, y1)-(x1, y2 - 1), 7

LINE (x2, y2)-(x1 + 1, y2), 5
LINE (x2, y2)-(x2, y1 + 1), 5

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
mouse.hide
IF WOrder(1) <> who THEN
        WinMakeHighest who
        WinUnDrw who
        WinDrwMng who
END IF
mouse.show
END SUB

SUB WinUnDrw (who)
GetStats who, crap$, x, y, w, h, state
IF state <> 0 THEN height = h ELSE height = TtlHeight
LINE (x, y)-(x + w, y + height), 4, BF

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

                WinDrwMng CW
                EXIT FOR
                END IF

        NEXT
        END IF
NEXT
END SUB
