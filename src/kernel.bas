'SNUGGLE OS ALPHA!
'Copyright 1999 Alexander Schrab
'Thanks to:
'UPA for help and ideas
'Mark K. Kim for the Vmouse routine (Couldn't have done it without you!!)


'***************
CONST LB = &H1      'constant for left button
'***************
CONST TtlHeight = 18
'Everything a window or an app owns lives in the heap (see 'The heap' below), in
'blocks of one kind. A block is reached by its handle: that number is the id of
'a window or a control.
CONST KWin = 1, KCtl = 2, KData = 3
CONST WfX = 0, WfY = 1, WfW = 2, WfH = 3, WfState = 4, WfApp = 5, WfData = 6, WinWords = 7
CONST CfKind = 0, CfX = 1, CfY = 2, CfW = 3, CfH = 4, CfChk = 5, CfGrp = 6, CtlWords = 7
'Controls
CONST CtlLabel = 1
CONST CtlButton = 2
CONST CtlCheck = 3
CONST CtlRadio = 4
CONST CtlText = 5
DIM SHARED GlyphData(1023) AS INTEGER   'characters 128 to 255, 16 row bytes each (characters 32 to 127 are read from SprData)
DIM SHARED Mask(15) AS INTEGER          'the 16 row bytes of the glyph being drawn, bit 7 is the left pixel

CONST HeapWords = 1023                  'the heap: 2 KB, enough for about 13 Hello windows
CONST HeapMax = 63                      'blocks at most
DIM SHARED Heap(HeapWords) AS INTEGER
DIM SHARED HBase(HeapMax) AS INTEGER    'first word of a block
DIM SHARED HSize(HeapMax) AS INTEGER    'words in a block, 0 for a free handle
DIM SHARED HOwner(HeapMax) AS INTEGER   'window the block belongs to (a window owns itself)
DIM SHARED HKind(HeapMax) AS INTEGER    'KWin, KCtl or KData
DIM SHARED HText(HeapMax) AS STRING     'title of a window, caption of a control
DIM SHARED HeapTop AS INTEGER           'first free word: the blocks fill 0 to HeapTop - 1, no gaps
CONST TimerMax = 16
DIM SHARED TmUsed(TimerMax) AS INTEGER         'timers: what to call and when (see TimerSet)
DIM SHARED TmApp(TimerMax) AS INTEGER
DIM SHARED TmWin(TimerMax) AS INTEGER
DIM SHARED TmTag(TimerMax) AS INTEGER
DIM SHARED TmStart(TimerMax) AS SINGLE
DIM SHARED TmDur(TimerMax) AS SINGLE
DIM SHARED UiMode AS INTEGER            'immediate mode controls: 0 draw, 1 find the one under the pointer, 2 click
DIM SHARED UiWin AS INTEGER             'the window being painted or probed, its client area, the pointer
DIM SHARED UiOx AS INTEGER
DIM SHARED UiOy AS INTEGER
DIM SHARED UiRight AS INTEGER
DIM SHARED UiBottom AS INTEGER
DIM SHARED UiMx AS INTEGER
DIM SHARED UiMy AS INTEGER
DIM SHARED UiHitId AS INTEGER           'mode 1: the button under the pointer and where it is
DIM SHARED UiHx1 AS INTEGER
DIM SHARED UiHy1 AS INTEGER
DIM SHARED UiHx2 AS INTEGER
DIM SHARED UiHy2 AS INTEGER
DIM SHARED UiDown AS INTEGER            'mode 0: the button that looks pressed, 0 for none
DIM SHARED UiClickId AS INTEGER         'mode 2: the button that was clicked
DIM SHARED ClientOpaque AS INTEGER      'WinDrwBrd leaves the client area alone: the app paints all of it
DIM SHARED DirtyN AS INTEGER            'rectangles an app marked for repaint (WinDirty), screen coordinates
DIM SHARED DirtyWin(8) AS INTEGER
DIM SHARED DirtyX1(8) AS INTEGER
DIM SHARED DirtyY1(8) AS INTEGER
DIM SHARED DirtyX2(8) AS INTEGER
DIM SHARED DirtyY2(8) AS INTEGER
DIM SHARED QuitFlag AS INTEGER           '-1 when the user asked to leave
DIM SHARED OomFlag AS INTEGER           '-1 when a block could not be had, set by MemAlloc
DIM SHARED WNumber AS INTEGER           'windows in WOrder, front first
DIM SHARED WNew AS INTEGER              'the window NewWin made last, 0 when it could not
DIM SHARED WOrder(HeapMax) AS INTEGER
DIM SHARED RL(1, 64, 4) AS INTEGER  'Repaint work lists of rectangles (x1, y1, x2, y2): the ones still to
                                        'paint, and the ones left after the next window. They swap roles.
DIM SHARED ClipCol AS INTEGER           'a clip one pixel thick is padded; these save the pixels
DIM SHARED ClipColX AS INTEGER          'the padding covers, so ClipOff can put them back
DIM SHARED ClipColY AS INTEGER
DIM SHARED ClipRow AS INTEGER
DIM SHARED ClipRowX AS INTEGER
DIM SHARED ClipRowY AS INTEGER
DIM SHARED VisOld(HeapMax) AS INTEGER   'which controls were drawn before a resize
DIM SHARED CtlFocus AS INTEGER          'text box that receives the keys, 0 for none
DIM SHARED CtlDown AS INTEGER           'button that is held down, 0 for none
DIM SHARED CtlEvent AS INTEGER          'control that was clicked or accepted, 0 for none
DIM SHARED SprData(9800) AS INTEGER     'ready-made glyphs 32 to 127 for each text style: PUT, no LINEs
DIM SHARED SprFg(2) AS INTEGER          'text styles: colour of the glyph and of the background behind it
DIM SHARED SprBg(2) AS INTEGER
DIM SHARED CoutBg AS INTEGER            'background colour behind the text cout draws, -1 for unknown
DIM SHARED NoSync AS INTEGER           'the tests set it: no wait for the retrace
DIM SHARED ClipActive AS INTEGER        'cout skips glyphs outside the clip
DIM SHARED ClipLX1 AS INTEGER           'the clip, the whole screen when ClipActive is 0
DIM SHARED ClipLY1 AS INTEGER
DIM SHARED ClipLX2 AS INTEGER
DIM SHARED ClipLY2 AS INTEGER
ClipLX2 = 639
ClipLY2 = 479
DIM SHARED Scratch(4100) AS INTEGER     'GET and PUT buffer: BlitMove uses all of it (8000 bytes), ClipOn saves
                                        'a column in 0 to 961 and a row in 1000 to 1162
DIM SHARED MouseAsm AS STRING    'machine code for the mouse driver call
DIM SHARED MouseOK AS INTEGER
DIM SHARED MouseVis AS INTEGER
DIM SHARED IconApp(7) AS INTEGER        'desktop icons: the app they start, where they are, their name
DIM SHARED IconX(7) AS INTEGER
DIM SHARED IconY(7) AS INTEGER
DIM SHARED IconText(7) AS STRING
DIM SHARED IconCount AS INTEGER


DEFINT A-Z
'@@RUN-BEGIN
SCREEN 12
enabled% = mouse.enable
mouse.show
Init
CLS

AppStartAll
refresh

DO
MainStep
LOOP UNTIL QuitFlag
'@@RUN-END

'One pass of the main loop: a click on a window or the desktop (it runs until
'the button goes up), a key, a control event, the timers. The tests call it
'with a scripted mouse.
SUB MainStep
IF mouse.getbutton = LB THEN
mouse.getpos cmx, cmy
hit = 0
FOR Cyc = 1 TO WNumber
CW = WOrder(Cyc)
part = WinPart(CW, cmx, cmy)
cid = 0
IF part = 8 THEN cid = CtlHit(CW, cmx, cmy)
SELECT CASE part
CASE 0
CASE 1 TO 3
        'a title bar button counts when the button goes up on it
        DO: LOOP WHILE mouse.getbutton = LB
        WinPutTop CW
        mouse.getpos cmx, cmy
        SELECT CASE WinPart(CW, cmx, cmy)
        CASE 1
                WinClose CW
        CASE 2
                IF HGet(CW, WfState) <> 2 THEN WinSetState CW, 2 ELSE WinSetState CW, 1
        CASE 3
                IF HGet(CW, WfState) <> 0 THEN WinSetState CW, 0 ELSE WinSetState CW, 1
        END SELECT
CASE 4
        CtlSetFocus 0
        WinPutTop CW
        IF HGet(CW, WfState) <> 2 THEN StartDrag 0, CW
CASE 5 TO 7
        WinPutTop CW
        IF HGet(CW, WfState) <> 2 THEN StartDrag part - 4, CW
CASE 8
        IF cid > 0 THEN
                WinPutTop CW
                CtlTrack cid
        ELSE
                CtlSetFocus 0
                WinPutTop CW
                IF UiClick(CW, cmx, cmy) = 0 THEN DO: LOOP WHILE mouse.getbutton = LB
        END IF
END SELECT
IF part <> 0 THEN hit = -1: EXIT FOR
NEXT
IF hit = 0 THEN
        'the desktop: an icon starts an instance of its app
        CtlSetFocus 0
        ic = IconAt(cmx, cmy)
        IF ic > 0 THEN
                DO: LOOP WHILE mouse.getbutton = LB
                AppLaunch IconApp(ic)
        END IF
END IF
END IF
k$ = ReadKey$
IF CtlFocus <> 0 THEN
        CtlKey k$
        k$ = ""
END IF
IF k$ <> "" AND WNumber > 0 THEN
        'keys go to the front window's app when it takes keys
        top = WOrder(1)
        IF AppWantsKeys(HGet(top, WfApp)) THEN
                AppKey HGet(top, WfApp), top, k$
                k$ = ""
        END IF
END IF
IF CtlEvent <> 0 THEN
        AppEvent HOwner(CtlEvent), CtlEvent
        CtlEvent = 0
END IF
TimersRun
IF UCASE$(k$) = "R" THEN refresh
IF UCASE$(k$) = "Q" THEN QuitFlag = -1
END SUB


'---------------------------------------------------------------------------
'Applications. An app is a set of procedures with its own number. The kernel
'starts every app once (AppStartAll) and hands a control event to the app that
'owns the window of the control (AppEvent). An app makes its windows with
'AppWindow, fills them with controls (CtlAdd) and changes them with the Ctl
'procedures; the kernel does the painting, the clipping and the mouse.
'Apps are added here by hand for now: a number, a start and an event procedure.
'---------------------------------------------------------------------------
'@@APP-BEGIN
'Make a window for app, with a data block of words words that the kernel frees
'when the window closes. Returns the window number, or 0 when the heap had no room
'for it (OomFlag is set; the controls an app adds to window 0 are refused, so an
'app need not check). Each window is moved 24 pixels down and right for every
'window already open, up to 5, so new windows do not hide one another. Control numbers and other state of an instance go in its
'block (AppGet, AppSet), so one app can run in several windows.
'@api Windows | Make a window of the app with a data block of `words` words, cascaded 24 px for each open window. Returns the window number, 0 when the heap has no room.
FUNCTION AppWindow (app, title$, x, y, w, h, words)
cascade = (WNumber MOD 6) * 24
NewWin title$, x + cascade, y + cascade, w, h
AppWindow = 0
IF WNew = 0 THEN EXIT FUNCTION
h = MemAlloc(WNew, KData, words)
IF h = 0 THEN
        WinClose WNew
        EXIT FUNCTION
END IF
HSet WNew, WfApp, app
HSet WNew, WfData, h
AppWindow = WNew
END FUNCTION

'@api Windows | Word `i` of the window's data block (0 when out of range).
FUNCTION AppGet (win, i)
AppGet = MemGet(HGet(win, WfData), i)
END FUNCTION

'@api Windows | Set word `i` of the window's data block (ignored when out of range).
SUB AppSet (win, i, v)
MemSet HGet(win, WfData), i, v
END SUB

'A block of one word that holds a string, owned by a window and freed with it.
'Returns its handle, 0 when the heap is full. BlockText$ and BlockSetText
'read and write the string (a handle that is not a data block reads "").
'@api Windows | A one word block owned by the window that holds a string. Returns its handle, 0 when the heap is full.
FUNCTION AppBlock (win)
AppBlock = MemAlloc(win, KData, 1)
END FUNCTION

'@api Windows | The string of a block made with `AppBlock`.
FUNCTION BlockText$ (h)
BlockText$ = ""
IF h >= 1 AND h <= HeapMax THEN
        IF HKind(h) = KData THEN BlockText$ = HText(h)
END IF
END FUNCTION

'@api Windows | Set the string of a block made with `AppBlock`.
SUB BlockSetText (h, t$)
IF h >= 1 AND h <= HeapMax THEN
        IF HKind(h) = KData THEN HText(h) = t$
END IF
END SUB

'Repaint the client area of a window after the app changed what it shows.
'@api Windows | Repaint the client area of a window after the app changed what it shows.
SUB WinInvalidate (who)
WinRect who, x1, y1, x2, y2
RepaintOwn who, x1, y1 + TtlHeight + 1, x2, y2
END SUB

'Mark a rectangle of the client area (x, y, w, h relative to it) as changed. WinFlush
'repaints everything marked, with one wait for the retrace. Only the marked
'rectangles are repainted, through the clip, so a game that moves little redraws
'little. More than eight marks in a row repaint what there is first.
'@api Windows | Mark a rectangle of the client area as changed (cut to the client area); `WinFlush` repaints the marks.
SUB WinDirty (who, x, y, w, h)
WinGeom who, wx, wy, ww, wh, state
x1 = wx + 3 + x
y1 = wy + TtlHeight + 4 + y
x2 = x1 + w - 1
y2 = y1 + h - 1
IF x1 < wx + 3 THEN x1 = wx + 3
IF y1 < wy + TtlHeight + 4 THEN y1 = wy + TtlHeight + 4
IF x2 > wx + ww - 3 THEN x2 = wx + ww - 3
IF y2 > wy + wh - 3 THEN y2 = wy + wh - 3
IF x1 > x2 OR y1 > y2 OR state = 0 THEN EXIT SUB
IF DirtyN >= 8 THEN WinFlush
DirtyN = DirtyN + 1
DirtyWin(DirtyN) = who
DirtyX1(DirtyN) = x1
DirtyY1(DirtyN) = y1
DirtyX2(DirtyN) = x2
DirtyY2(DirtyN) = y2
END SUB

'@api Windows | Repaint the rectangles marked with `WinDirty`.
SUB WinFlush
IF DirtyN = 0 THEN EXIT SUB
mouse.hide
WaitRetrace
FOR i = 1 TO DirtyN
        RepaintWin DirtyWin(i), DirtyX1(i), DirtyY1(i), DirtyX2(i), DirtyY2(i)
NEXT
DirtyN = 0
mouse.show
END SUB

'Start an instance of an app and show its window.
SUB AppLaunch (app)
WNew = 0
OomFlag = 0
CtlSetFocus 0
AppRun app
IF OomFlag = 0 THEN
        IF WNew > 0 THEN WinShow WNew
ELSE
        'Out of memory: take back what the instance got, and say so.
        IF HKind(WNew) = KWin THEN WinClose WNew
        Notice "Out of memory. The app was not started."
END IF
END SUB

'@@APPS-HERE
'@@APP-END

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

SUB cout (text$, sx, sy, colo, Lengh, break)
'A known background and colour pair has ready-made glyphs.
st = -1
IF CoutBg >= 0 THEN
        FOR i = 0 TO 2
                IF SprFg(i) = colo AND SprBg(i) = CoutBg THEN st = i
        NEXT
END IF

charlengh = Lengh \ 8
RowChar = 0
FOR Char = 1 TO LEN(text$)
        RowChar = RowChar + 1
        IF RowChar > charlengh THEN
                IF break = 1 THEN sy = sy + 16: RowChar = 1 ELSE EXIT FOR
        END IF
        Glyph sx + (RowChar - 1) * 8, sy + 1, ASC(MID$(text$, Char, 1)), colo, st
NEXT
END SUB

'The 8 x 16 glyph of every character comes from QBasic's own screen font: the
'character is printed in colour 1 (one bit plane) and read back with GET.
'Characters 128 to 255 are kept as row bytes. Characters 32 to 127 become ready-
'made glyphs for each text style, and style 1 (black on white) doubles as their
'row bytes. Characters below 32 have no glyph.
SUB CoutSetup
COLOR 1
Pal 1, 0, 0, 0

FOR a = 128 TO 255
        LOCATE 1, 1
        PRINT CHR$(a);
        GET (0, 0)-(7, 15), Scratch
        FOR r = 0 TO 14 STEP 2
                b0 = Scratch(2 + r * 2) AND &HFF
                b1 = Scratch(4 + r * 2) AND &HFF
                IF b1 > 127 THEN GlyphData((a - 128) * 8 + r \ 2) = b0 + (b1 - 256) * 256 ELSE GlyphData((a - 128) * 8 + r \ 2) = b0 + b1 * 256
        NEXT
NEXT

'Ready-made glyphs: title text, text on the client area, text on a button.
SprFg(0) = 2: SprBg(0) = 6
SprFg(1) = 0: SprBg(1) = 15
SprFg(2) = 0: SprBg(2) = 3
CoutBg = -1
FOR c = 32 TO 127
        LOCATE 1, 1
        PRINT CHR$(c);
        GET (0, 0)-(7, 15), Scratch
        FOR r = 0 TO 15
                Mask(r) = Scratch(2 + r * 2) AND &HFF
        NEXT
        FOR st = 0 TO 2
                gFill 0, 0, 7, 15, SprBg(st)
                GlyphRows 0, 0, SprFg(st)
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

'The next key, "" when there is none.
FUNCTION ReadKey$
ReadKey$ = INKEY$
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
FOR i = 1 TO TimerMax
        IF TmWin(i) = who AND TmApp(i) > 0 THEN TmUsed(i) = 0
NEXT
IF HSize(CtlFocus) = 0 THEN CtlFocus = 0
IF HSize(CtlDown) = 0 THEN CtlDown = 0
Repaint x1, y1, x2, y2
END SUB

'A line of text on a bar at the bottom of the screen. The next repaint of that
'area removes it.
'@api Windows | Show a line of text on the bar at the bottom of the screen for 4 seconds.
SUB Notice (msg$)
mouse.hide
gFill 0, 464, 639, 479, 5
cout msg$, 8, 463, 15, 624, 0
mouse.show
TimerSet 0, 0, 1, 4
END SUB

'---------------------------------------------------------------------------
'Immediate mode controls. A button or label of an app that has a paint
'procedure (manifest paint=) is not stored anywhere: the app declares it each
'time its window is painted, with UiButton and UiLabel, and the kernel runs the
'same procedure to find a click. So they cost no heap and no handles, and their
'state is whatever the app keeps in its data block. A button id is a number the
'app chooses, 1 or more and unique in the procedure (0 means no button).
'  mode 0 draws, mode 1 finds the button under the pointer, mode 2 returns -1
'  for the button that was clicked, and the app does the work in its IF.
'---------------------------------------------------------------------------
'Run the app's paint procedure for a window in a mode.
SUB UiRun (who, md)
oldmode = UiMode
oldwin = UiWin
UiMode = md
UiWin = who
WinGeom who, x, y, w, h, state
UiOx = x + 3
UiOy = y + TtlHeight + 4
UiRight = x + w - 3
UiBottom = y + h - 3
AppPaint HGet(who, WfApp), who
UiMode = oldmode
UiWin = oldwin
END SUB

'A push button at x, y (relative to the client area). In mode 2 it returns -1
'when it is the clicked one. A button that does not fit in the client area is
'neither drawn nor hit, as for retained controls.
'@api Immediate mode | A push button (`id` 1 or more, x and y relative to the client area). Returns -1 when it was clicked (only in the click pass), so the app does its work in the IF.
FUNCTION UiButton (id, x, y, w, h, cap$)
UiButton = 0
IF id < 1 THEN EXIT FUNCTION
x1 = UiOx + x
y1 = UiOy + y
x2 = x1 + w - 1
y2 = y1 + h - 1
IF x1 < UiOx OR y1 < UiOy OR x2 > UiRight OR y2 > UiBottom THEN EXIT FUNCTION
SELECT CASE UiMode
CASE 0
        IF NOT Outside(x1, y1, x2, y2) THEN DrawPush x1, y1, x2, y2, cap$, (UiDown = id)
CASE 1
        IF UiMx >= x1 AND UiMx <= x2 AND UiMy >= y1 AND UiMy <= y2 THEN
                UiHitId = id
                UiHx1 = x1: UiHy1 = y1: UiHx2 = x2: UiHy2 = y2
        END IF
CASE 2
        IF id = UiClickId THEN UiButton = -1
END SELECT
END FUNCTION

'The size of the client area in pixels, for an app that paints all of it.
'@api Immediate mode | Width of the client area, in a paint procedure.
FUNCTION UiW
UiW = UiRight - UiOx + 1
END FUNCTION

'@api Immediate mode | Height of the client area, in a paint procedure.
FUNCTION UiH
UiH = UiBottom - UiOy + 1
END FUNCTION

'A filled rectangle in a colour, x and y relative to the client area. It is
'cut to the client area, so a game can let things slide in and out (drawing only).
'@api Immediate mode | A filled rectangle in colour `c`, relative to the client area and cut to it.
SUB UiFill (x, y, w, h, c)
IF UiMode <> 0 THEN EXIT SUB
x1 = UiOx + x
y1 = UiOy + y
x2 = x1 + w - 1
y2 = y1 + h - 1
IF x1 < UiOx THEN x1 = UiOx
IF y1 < UiOy THEN y1 = UiOy
IF x2 > UiRight THEN x2 = UiRight
IF y2 > UiBottom THEN y2 = UiBottom
IF x1 <= x2 AND y1 <= y2 THEN gFill x1, y1, x2, y2, c
END SUB

'Text in black on the client background (drawing only).
'@api Immediate mode | Text in black on the client area, `h` high.
SUB UiLabel (x, y, w, h, t$)
IF UiMode <> 0 THEN EXIT SUB
x1 = UiOx + x
y1 = UiOy + y
IF x1 < UiOx OR y1 < UiOy OR x1 + w - 1 > UiRight OR y1 + h - 1 > UiBottom THEN EXIT SUB
CtlCap t$, x1, y1 + (h - 16) \ 2 - 1, w, 15
END SUB

'Click a button by its id: the app's procedure runs in mode 2, then the client
'area is repainted, since the app may have changed what it shows.
SUB UiFire (who, id)
UiClickId = id
UiRun who, 2
UiClickId = 0
WinInvalidate who
END SUB

'A click at a screen point in a window. Returns -1 when an immediate button
'took it: it looks pressed while the pointer is on it, and counts when the
'button goes up on it.
FUNCTION UiClick (who, mx, my)
UiClick = 0
UiMx = mx
UiMy = my
UiHitId = 0
UiRun who, 1
IF UiHitId = 0 THEN EXIT FUNCTION
UiClick = -1
id = UiHitId
x1 = UiHx1: y1 = UiHy1: x2 = UiHx2: y2 = UiHy2
UiDown = id
Repaint x1, y1, x2, y2
isin = -1
DO
        mouse.getpos mx, my
        over = (mx >= x1 AND mx <= x2 AND my >= y1 AND my <= y2)
        IF over <> isin THEN
                isin = over
                IF isin THEN UiDown = id ELSE UiDown = 0
                Repaint x1, y1, x2, y2
        END IF
LOOP WHILE mouse.getbutton = LB
'where the pointer is now decides, not where it was at the last look
mouse.getpos mx, my
isin = (mx >= x1 AND mx <= x2 AND my >= y1 AND my <= y2)
UiDown = 0
IF isin THEN UiFire who, id ELSE Repaint x1, y1, x2, y2
END FUNCTION

'---------------------------------------------------------------------------
'Timers. TimerSet(app, win, tag, seconds) makes the kernel call back once, when
'the time is up, from the main loop (TimersRun): the kernel for app 0, else
'AppTimer app, win, tag. The same app, window and tag set again starts over.
'A window's timers go when it closes. The clock is the system clock (TIMER),
'good to about 1/100 s; a callback waits while the program is in a drag or a
'button press.
'---------------------------------------------------------------------------
'@api Timers | Call the app's timer procedure once after `secs!` seconds with `tag`. Setting the same app, window and tag again starts over.
SUB TimerSet (app, win, tag, secs!)
s = 0
FOR i = 1 TO TimerMax
        IF TmUsed(i) THEN
                IF TmApp(i) = app AND TmWin(i) = win AND TmTag(i) = tag THEN s = i
        ELSEIF f = 0 THEN
                f = i
        END IF
NEXT
IF s = 0 THEN s = f
IF s = 0 THEN EXIT SUB
TmUsed(s) = -1
TmApp(s) = app
TmWin(s) = win
TmTag(s) = tag
TmStart(s) = TIMER
TmDur(s) = secs!
END SUB

SUB TimersRun
FOR i = 1 TO TimerMax
        IF TmUsed(i) THEN
                e! = TIMER - TmStart(i)
                IF e! < 0 THEN e! = e! + 86400
                IF e! >= TmDur(i) THEN
                        TmUsed(i) = 0
                        IF TmApp(i) = 0 THEN
                                'kernel tag 1: take the notice off the bottom bar
                                Repaint 0, 464, 639, 479
                        ELSE
                                AppTimer TmApp(i), TmWin(i), TmTag(i)
                        END IF
                END IF
        END IF
NEXT
END SUB

'Repaint the area of a window, for a window that was just made.
SUB WinShow (who)
WinRect who, x1, y1, x2, y2
Repaint x1, y1, x2, y2
END SUB

'---------------------------------------------------------------------------
'Desktop icons: a picture and a name on the background. A click on one starts
'an instance of its app (AppLaunch). They are drawn with the background, so a
'window that moves over one never needs to know about it.
'---------------------------------------------------------------------------
SUB IconAdd (app, label$)
IF IconCount >= 7 THEN EXIT SUB
IconCount = IconCount + 1
IconApp(IconCount) = app
IconText(IconCount) = label$
IconX(IconCount) = 24
IconY(IconCount) = 16 + (IconCount - 1) * 64
END SUB

'The icon at a screen point, 0 for none. The name belongs to the icon.
FUNCTION IconAt (mx, my)
IconAt = 0
FOR i = 1 TO IconCount
        IF mx >= IconX(i) - 16 AND mx <= IconX(i) + 48 AND my >= IconY(i) AND my <= IconY(i) + 50 THEN IconAt = i
NEXT
END FUNCTION

'Draw the icons that touch the clip, or the screen when there is no clip.
SUB IconsDraw
FOR i = 1 TO IconCount
        x = IconX(i)
        y = IconY(i)
        n = LEN(IconText(i))
        IF NOT Outside(x - 16, y, x + 48, y + 50) THEN
                DrwBtn x, y, 31, 31
                gBox x + 7, y + 8, x + 24, y + 23, 1
                gFill x + 8, y + 9, x + 23, y + 11, 6
                gFill x + 8, y + 12, x + 23, y + 22, 15
                cout IconText(i), x + 16 - n * 4, y + 33, 15, n * 8, 0
        END IF
NEXT
END SUB

'Fill a free part of the background and put the icons on it.
SUB DeskFill (x1, y1, x2, y2)
IF IconCount = 0 THEN
        gFill x1, y1, x2, y2, 4
ELSE
        ClipOn x1, y1, x2, y2
        gFill x1, y1, x2, y2, 4
        IconsDraw
        ClipOff
END IF
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

'---------------------------------------------------------------------------
'The heap. One array, blocks packed from word 0 with no gaps. A block is used
'through its handle (1 to HeapMax), so the heap can move it: a free slides every
'block above it down. There is no separate collection pass.
'---------------------------------------------------------------------------
'A block of n words of a kind, zeroed, owned by a window. Returns its handle.
'When the heap or the handles are full it returns 0 and sets OomFlag.
'@api Heap | A zeroed block of `n` words of a kind (KData for app data) owned by a window. Returns its handle, 0 and OomFlag when full.
FUNCTION MemAlloc (owner, kind, n)
MemAlloc = 0
IF n < 1 THEN EXIT FUNCTION
IF HeapTop + n <= HeapWords + 1 THEN
        FOR h = 1 TO HeapMax
                IF HSize(h) = 0 THEN
                        HBase(h) = HeapTop
                        HSize(h) = n
                        HOwner(h) = owner
                        HKind(h) = kind
                        FOR i = HeapTop TO HeapTop + n - 1
                                Heap(i) = 0
                        NEXT
                        HeapTop = HeapTop + n
                        MemAlloc = h
                        EXIT FUNCTION
                END IF
        NEXT
END IF
OomFlag = -1
END FUNCTION

'@api Heap | Free one block and close the gap.
SUB MemFree (h)
n = HSize(h)
IF n = 0 THEN EXIT SUB
b = HBase(h)
FOR i = b TO HeapTop - n - 1
        Heap(i) = Heap(i + n)
NEXT
FOR k = 1 TO HeapMax
        IF HSize(k) > 0 AND HBase(k) > b THEN HBase(k) = HBase(k) - n
NEXT
HeapTop = HeapTop - n
HSize(h) = 0
HKind(h) = 0
HText(h) = ""
END SUB

'Word f of a window or control block, and set it. No range check: the kernel
'knows its own blocks. An app goes through MemGet and MemSet.
FUNCTION HGet (h, f)
HGet = Heap(HBase(h) + f)
END FUNCTION

SUB HSet (h, f, v)
Heap(HBase(h) + f) = v
END SUB

'Free every block a window owns (what closing an instance does).
'@api Heap | Free every block a window owns.
SUB MemFreeAll (owner)
FOR h = 1 TO HeapMax
        IF HSize(h) > 0 AND HOwner(h) = owner THEN MemFree h
NEXT
END SUB

'Word i of a block. An index outside the block reads 0 and writes nothing.
'@api Heap | Word `i` of a block (0 when out of range).
FUNCTION MemGet (h, i)
MemGet = 0
IF h >= 1 AND h <= HeapMax THEN IF i >= 0 AND i < HSize(h) THEN MemGet = Heap(HBase(h) + i)
END FUNCTION

'@api Heap | Set word `i` of a block (ignored when out of range).
SUB MemSet (h, i, v)
IF h >= 1 AND h <= HeapMax THEN IF i >= 0 AND i < HSize(h) THEN Heap(HBase(h) + i) = v
END SUB

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
'part that is on the screen before and after can be.
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

'Draw the glyph in Mask as runs of set pixels, from the top left corner gx, gy.
SUB GlyphRows (gx, gy, colo)
FOR r = 0 TO 15
        m = Mask(r)
        bit = 128
        x0 = -1
        FOR x = 0 TO 8
                IF (m AND bit) <> 0 THEN
                        IF x0 < 0 THEN x0 = x
                ELSEIF x0 >= 0 THEN
                        gLine gx + x0, gy + r, gx + x - 1, gy + r, colo
                        x0 = -1
                END IF
                bit = bit \ 2
        NEXT
NEXT
END SUB

'One character at gx, gy. A glyph that is inside the clip and has a ready-made
'sprite for the style st is one PUT. At the edge of the clip, or without a style,
'it goes out as runs, which LINE clips.
SUB Glyph (gx, gy, num, colo, st)
IF gx + 7 < ClipLX1 OR gx > ClipLX2 OR gy + 15 < ClipLY1 OR gy > ClipLY2 THEN EXIT SUB
whole = gx >= ClipLX1 AND gx + 7 <= ClipLX2 AND gy >= ClipLY1 AND gy + 15 <= ClipLY2
IF num < 32 THEN EXIT SUB
IF st >= 0 AND whole AND num < 128 THEN
        spr = (st * 96 + num - 32) * 34
        gPutSpr gx, gy, spr
        EXIT SUB
END IF
IF num < 128 THEN
        gb = (96 + num - 32) * 34 + 2
        FOR r = 0 TO 15
                Mask(r) = (NOT SprData(gb + r * 2)) AND &HFF
        NEXT
ELSE
        FOR r = 0 TO 15
                v = GlyphData((num - 128) * 8 + r \ 2)
                IF r AND 1 THEN Mask(r) = ((v AND &HFF00) \ 256) AND &HFF ELSE Mask(r) = v AND &HFF
        NEXT
END IF
GlyphRows gx, gy, colo
END SUB

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

'---------------------------------------------------------------------------
'Controls. A control belongs to a window and is drawn in its client area, after
'the frame, so it is repainted (and clipped) with the window. A control that
'does not fit inside the client area is not drawn and cannot be hit.
'Events are not callbacks: a click or an accepted text box sets CtlEvent to the
'control number, and the main loop reads it.
'---------------------------------------------------------------------------

'Add a control to a window and return its number. 0 when the heap is full
'(OomFlag), or when the window is 0, a window that could not be made.
'x, y, w, h are relative to the top left of the client area.
'@api Controls | Add a retained control (CtlLabel, CtlButton, CtlCheck, CtlRadio or CtlText) to a window. Returns its number, 0 when the heap is full.
FUNCTION CtlAdd (win, kind, x, y, w, h, cap$)
CtlAdd = 0
IF win < 1 THEN EXIT FUNCTION
id = MemAlloc(win, KCtl, CtlWords)
IF id = 0 THEN EXIT FUNCTION
HSet id, CfKind, kind
HSet id, CfX, x
HSet id, CfY, y
HSet id, CfW, w
HSet id, CfH, h
HSet id, CfGrp, 1
HText(id) = cap$
CtlAdd = id
END FUNCTION

'The screen rectangle of a control, both ends included.
SUB CtlRect (id, x1, y1, x2, y2)
WinGeom HOwner(id), wx, wy, ww, wh, wstate
b = HBase(id)
x1 = wx + 3 + Heap(b + CfX)
y1 = wy + TtlHeight + 4 + Heap(b + CfY)
x2 = x1 + Heap(b + CfW) - 1
y2 = y1 + Heap(b + CfH) - 1
END SUB

'-1 when the control is drawn: its window is not rolled up and the whole
'control is inside the client area.
FUNCTION CtlVisible (id)
CtlVisible = 0
WinGeom HOwner(id), x, y, w, h, state
IF state = 0 THEN EXIT FUNCTION
CtlRect id, x1, y1, x2, y2
IF x1 >= x + 3 AND y1 >= y + TtlHeight + 4 AND x2 <= x + w - 3 AND y2 <= y + h - 3 THEN CtlVisible = -1
END FUNCTION

SUB CtlDraw (id)
CtlRect id, x1, y1, x2, y2
w = HGet(id, CfW)
h = HGet(id, CfH)
cap$ = HText(id)
ty = y1 + (h - 16) \ 2 - 1
SELECT CASE HGet(id, CfKind)
CASE CtlLabel
        CtlCap cap$, x1, ty, w, 15
CASE CtlButton
        DrawPush x1, y1, x2, y2, cap$, (CtlDown = id)
CASE CtlCheck
        bx = y1 + (h - 13) \ 2
        gBox x1, bx, x1 + 12, bx + 12, 1
        gFill x1 + 1, bx + 1, x1 + 11, bx + 11, 15
        IF HGet(id, CfChk) THEN
                gLine x1 + 3, bx + 3, x1 + 9, bx + 9, 0
                gLine x1 + 3, bx + 4, x1 + 8, bx + 9, 0
                gLine x1 + 9, bx + 3, x1 + 3, bx + 9, 0
                gLine x1 + 9, bx + 4, x1 + 4, bx + 9, 0
        END IF
        CtlCap cap$, x1 + 20, ty, w - 20, 15
CASE CtlRadio
        cx = x1 + 6
        cy = y1 + h \ 2
        gFill cx - 6, cy - 6, cx + 6, cy + 6, 15
        gCircle cx, cy, 6, 1
        IF HGet(id, CfChk) THEN gFill cx - 2, cy - 2, cx + 2, cy + 2, 0
        CtlCap cap$, x1 + 20, ty, w - 20, 15
CASE CtlText
        IF CtlFocus = id THEN bc = 7 ELSE bc = 1
        gBox x1, y1, x2, y2, bc
        gFill x1 + 1, y1 + 1, x2 - 1, y2 - 1, 15
        n = (w - 8) \ 8
        shown$ = cap$
        IF LEN(shown$) > n THEN shown$ = RIGHT$(shown$, n)
        CtlCap shown$, x1 + 4, ty, w - 8, 15
        IF CtlFocus = id THEN
                cx = x1 + 4 + LEN(shown$) * 8
                gLine cx, y1 + 3, cx, y2 - 3, 0
        END IF
END SELECT
END SUB

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

'Draw the controls of one window, in the order they were added. A control
'outside the clip, or not entirely inside the client area, is not drawn.
SUB CtlDrawAll (who)
WinGeom who, x, y, w, h, state
IF state = 0 THEN EXIT SUB
ox = x + 3
oy = y + TtlHeight + 4
FOR i = 1 TO HeapMax
        IF HKind(i) = KCtl AND HOwner(i) = who THEN
                x1 = ox + HGet(i, CfX)
                y1 = oy + HGet(i, CfY)
                x2 = x1 + HGet(i, CfW) - 1
                y2 = y1 + HGet(i, CfH) - 1
                IF x1 >= ox AND y1 >= oy AND x2 <= x + w - 3 AND y2 <= y + h - 3 THEN
                        IF NOT Outside(x1, y1, x2, y2) THEN CtlDraw i
                END IF
        END IF
NEXT
END SUB

'Repaint one control (and whatever covers part of it) after its state changed.
SUB CtlRedraw (id)
IF id < 1 OR id > HeapMax THEN EXIT SUB
IF HKind(id) <> KCtl THEN EXIT SUB
IF NOT CtlVisible(id) THEN EXIT SUB
CtlRect id, x1, y1, x2, y2
'Is a window in front of this one over the control?
covered = 0
FOR Cyc = 1 TO WNumber
        CW = WOrder(Cyc)
        IF CW = HOwner(id) THEN EXIT FOR
        WinRect CW, wx1, wy1, wx2, wy2
        IF NOT (wx2 < x1 OR wx1 > x2 OR wy2 < y1 OR wy1 > y2) THEN
                covered = -1
                EXIT FOR
        END IF
NEXT
IF covered THEN
        RepaintOwn HOwner(id), x1, y1, x2, y2
ELSE
        'Nothing in front: the client background, then the controls of this
        'window that touch the rectangle, in the order they were added.
        'only the part on the screen: VIEW SCREEN refuses the rest
        IF x1 < 0 THEN x1 = 0
        IF y1 < 0 THEN y1 = 0
        IF x2 > 639 THEN x2 = 639
        IF y2 > 479 THEN y2 = 479
        IF x1 > x2 OR y1 > y2 THEN EXIT SUB
        mouse.hide
        WaitRetrace
        ClipOn x1, y1, x2, y2
        gFill x1, y1, x2, y2, 15
        FOR i = 1 TO HeapMax
                IF HKind(i) = KCtl AND HOwner(i) = HOwner(id) THEN
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
FOR i = HeapMax TO 1 STEP -1
        IF HKind(i) = KCtl AND HOwner(i) = who AND HGet(i, CfKind) <> CtlLabel THEN
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
'@api Controls | Give the keys to a text box, 0 for none.
SUB CtlSetFocus (id)
old = CtlFocus
IF old = id THEN EXIT SUB
CtlFocus = id
IF old > 0 THEN CtlRedraw old
IF id > 0 THEN CtlRedraw id
END SUB

'Select one radio button of its group.
'@api Controls | Select a radio button and clear the others of its group.
SUB CtlSelect (id)
FOR i = 1 TO HeapMax
        IF i <> id AND HKind(i) = KCtl AND HGet(i, CfKind) = CtlRadio AND HOwner(i) = HOwner(id) AND HGet(i, CfGrp) = HGet(id, CfGrp) THEN
                IF HGet(i, CfChk) <> 0 THEN
                        HSet i, CfChk, 0
                        CtlRedraw i
                END IF
        END IF
NEXT
IF HGet(id, CfChk) = 0 THEN
        HSet id, CfChk, 1
        CtlRedraw id
END IF
END SUB

'What a click on a control does, after the button went up on it.
SUB CtlActivate (id)
SELECT CASE HGet(id, CfKind)
CASE CtlButton
        CtlEvent = id
CASE CtlCheck
        IF HGet(id, CfChk) THEN HSet id, CfChk, 0 ELSE HSet id, CfChk, 1
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
IF HGet(id, CfKind) = CtlButton THEN
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
        mouse.getpos mx, my
        isin = (mx >= x1 AND mx <= x2 AND my >= y1 AND my <= y2)
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
SUB CtlKey (k$)
id = CtlFocus
IF id = 0 OR LEN(k$) <> 1 THEN EXIT SUB
IF HGet(id, CfKind) <> CtlText THEN EXIT SUB
c = ASC(k$)
cur$ = HText(id)
SELECT CASE c
CASE 8
        IF LEN(cur$) > 0 THEN
                HText(id) = LEFT$(cur$, LEN(cur$) - 1)
                CtlRedraw id
        END IF
CASE 13
        CtlEvent = id
CASE 27
        CtlSetFocus 0
CASE IS >= 32
        IF LEN(cur$) < 40 THEN
                HText(id) = cur$ + k$
                CtlRedraw id
        END IF
END SELECT
END SUB

'@api Controls | Set the text of a control and repaint it.
SUB CtlSetText (id, t$)
HText(id) = t$
CtlRedraw id
END SUB

'@api Controls | The text of a control (the text box content, a caption).
FUNCTION CtlGetText$ (id)
CtlGetText$ = HText(id)
END FUNCTION

'Check or uncheck a checkbox or radio button. Use CtlSelect for a radio button
'that must exclude the others of its group.
'@api Controls | Check or uncheck a check box or radio button.
SUB CtlSetChecked (id, v)
IF v <> 0 THEN HSet id, CfChk, 1 ELSE HSet id, CfChk, 0
CtlRedraw id
END SUB

'@api Controls | -1 when a check box or radio button is checked.
FUNCTION CtlGetChecked (id)
IF HGet(id, CfChk) <> 0 THEN CtlGetChecked = -1 ELSE CtlGetChecked = 0
END FUNCTION
