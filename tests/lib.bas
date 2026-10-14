'One line appended to RESULT.TXT, so progress shows while the run is going.
SUB Emit (s$)
OPEN "RESULT.TXT" FOR APPEND AS #2
PRINT #2, s$
CLOSE #2
END SUB

SUB Check (lbl$, ok, info$)
TestCount = TestCount + 1
IF ok THEN
        Emit "PASS " + lbl$
ELSE
        TestFails = TestFails + 1
        Emit "FAIL " + lbl$ + " " + info$
END IF
END SUB

SUB Metric (lbl$, v!)
Emit "METRIC " + lbl$ + " " + STR$(v!)
END SUB

'Dump the four bit planes of the screen to S<nnn><side><plane>.BIN (BSAVE, native
'speed). The host script compares side A with side B and reports the pixels.
SUB Dump (side$)
FOR p = 0 TO 3
        OUT &H3CE, 4
        OUT &H3CF, p
        DEF SEG = &HA000
        BSAVE "S" + RIGHT$("000" + LTRIM$(STR$(SnapNo)), 3) + side$ + CHR$(48 + p) + ".BIN", 0, 38400
        DEF SEG
NEXT
OUT &H3CF, 0
END SUB

'Length of [a..b] inside [lo..hi]. Works on copies: the arguments are the callers' variables.
FUNCTION ClipSpan (a, b, lo, hi)
s = a: e = b
IF s > e THEN SWAP s, e
IF s < lo THEN s = lo
IF e > hi THEN e = hi
IF e >= s THEN ClipSpan = e - s + 1 ELSE ClipSpan = 0
END FUNCTION

FUNCTION ClipArea& (x1, y1, x2, y2)
ClipArea& = CLNG(ClipSpan(x1, x2, 0, 639)) * ClipSpan(y1, y2, 0, 479)
END FUNCTION

FUNCTION InterArea& (ax1, ay1, ax2, ay2, bx1, by1, bx2, by2)
x1 = ax1: IF bx1 > x1 THEN x1 = bx1
y1 = ay1: IF by1 > y1 THEN y1 = by1
x2 = ax2: IF bx2 < x2 THEN x2 = bx2
y2 = ay2: IF by2 < y2 THEN y2 = by2
IF x1 > x2 OR y1 > y2 THEN InterArea& = 0 ELSE InterArea& = ClipArea&(x1, y1, x2, y2)
END FUNCTION

'Window sets used by the cases. Index 1 is the back window, the last is the front.
SUB Scene (n)
WinReset
SELECT CASE n
CASE 1
        NewWin "Alfa", 90, 90, 300, 70
        NewWin "Beta", 100, 100, 300, 70
        NewWin "Welcome to the future", 120, 120, 300, 100
CASE 2
        NewWin "Back window", 10, 10, 200, 150
        NewWin "Second", 100, 60, 250, 120
        NewWin "A rolled up window with a long title", 300, 200, 300, 200
        NewWin "Half off screen", 500, 400, 200, 150
        NewWin "Small", 50, 300, 120, 60
        NewWin "Front", 250, 150, 90, 40
        WGData(3, 5) = 0
CASE 3
        NewWin "Left", 0, 0, 320, 240
        NewWin "Right", 320, 240, 320, 240
        NewWin "Maximised", 200, 100, 200, 100
        WGData(3, 5) = 2
CASE 4
        'Controls 1 to 9 in window 1; window 2 covers part of the Clear button.
        NewWin "Controls", 40, 30, 340, 230
        id = CtlAdd(1, CtlLabel, 8, 6, 60, 16, "Name:")
        id = CtlAdd(1, CtlText, 70, 4, 200, 22, "snuggle")
        id = CtlAdd(1, CtlCheck, 8, 36, 160, 16, "Enable sound")
        id = CtlAdd(1, CtlRadio, 8, 62, 100, 16, "Red")
        id = CtlAdd(1, CtlRadio, 8, 82, 100, 16, "Green")
        id = CtlAdd(1, CtlRadio, 8, 102, 100, 16, "Blue")
        id = CtlAdd(1, CtlButton, 8, 136, 80, 26, "OK")
        id = CtlAdd(1, CtlButton, 100, 136, 80, 26, "Clear")
        id = CtlAdd(1, CtlLabel, 8, 176, 300, 16, "Ready")
        Ctl(4).chk = 1
        NewWin "Cover", 200, 120, 200, 120
END SELECT
END SUB

'Dump the screen as the incremental code left it (side A), paint the reference
'over it, and dump that (side B). The host compares the two.
SUB CompareToLegacy (lbl$)
SnapNo = SnapNo + 1
Dump "A"
RefPaintAll
Dump "B"
Emit "SNAP" + STR$(SnapNo) + " " + lbl$
END SUB

'Draw one primitive both ways on a blank screen and compare.
SUB ComparePrim (kind, x1, y1, x2, y2)
gFill 0, 0, 639, 479, 8
SELECT CASE kind
CASE 1: WinDrwBrd x1, y1, x2, y2
CASE 2: WinDrwTtl x1, y1, x2, y2
CASE 3: DrwBtn x1, y1, x2 - x1, y2 - y1
END SELECT
SnapNo = SnapNo + 1
Dump "A"
gFill 0, 0, 639, 479, 8
SELECT CASE kind
CASE 1: RefWinDrwBrd x1, y1, x2, y2
CASE 2: RefWinDrwTtl x1, y1, x2, y2
CASE 3: RefDrwBtn x1, y1, x2 - x1, y2 - y1, 1
END SELECT
Dump "B"
Emit "SNAP" + STR$(SnapNo) + " primitive" + STR$(kind) + STR$(x1) + STR$(y1) + STR$(x2) + STR$(y2)
END SUB

'Pixels written by one drag step, new way and old way, per pixel of the area
'the step has to change (old rectangle plus new rectangle).
SUB MeasureDrag (lbl$, who, dx, dy)
WinRect who, ox1, oy1, ox2, oy2
WGData(who, 1) = WGData(who, 1) + dx
WGData(who, 2) = WGData(who, 2) + dy
WinRect who, nx1, ny1, nx2, ny2
WGData(who, 1) = WGData(who, 1) - dx
WGData(who, 2) = WGData(who, 2) - dy
area& = ClipArea&(ox1, oy1, ox2, oy2) + ClipArea&(nx1, ny1, nx2, ny2) - InterArea&(ox1, oy1, ox2, oy2, nx1, ny1, nx2, ny2)

gWrites = 0
WinMoveTo who, WGData(who, 1) + dx, WGData(who, 2) + dy
newW& = gWrites
WinMoveTo who, WGData(who, 1) - dx, WGData(who, 2) - dy

gWrites = 0
LegacyMoveTo who, WGData(who, 1) + dx, WGData(who, 2) + dy
oldW& = gWrites
LegacyMoveTo who, WGData(who, 1) - dx, WGData(who, 2) - dy

newR! = newW& / area&
oldR! = oldW& / area&
Metric lbl$ + " changed-pixels", CSNG(area&)
Metric lbl$ + " writes-per-pixel new", newR!
Metric lbl$ + " writes-per-pixel legacy", oldR!
Check lbl$ + " new way writes at most 1.5 per changed pixel", newR! <= 1.5, STR$(newR!)
Check lbl$ + " new way writes under half of the old way", newW& * 2 < oldW&, STR$(newW&) + " vs" + STR$(oldW&)
END SUB

'Text drawn with cout against the same characters printed by QBasic (80 per
'row, characters 32 to 255). QBasic's own printing is the reference font.
SUB GlyphCase (colo)
gFill 0, 0, 639, 479, 0
COLOR colo
FOR rw = 0 TO 2
        t$ = ""
        FOR c = 0 TO 79
                n = 32 + rw * 80 + c
                IF n <= 255 THEN t$ = t$ + CHR$(n)
        NEXT
        LOCATE rw + 1, 1
        PRINT t$;
NEXT
SnapNo = SnapNo + 1
Dump "A"
gFill 0, 0, 639, 479, 0
FOR rw = 0 TO 2
        t$ = ""
        FOR c = 0 TO 79
                n = 32 + rw * 80 + c
                IF n <= 255 THEN t$ = t$ + CHR$(n)
        NEXT
        cout t$, 0, rw * 16 - 1, colo, 640, 0
NEXT
Dump "B"
Emit "SNAP" + STR$(SnapNo) + " glyphs: cout equals PRINT, colour" + STR$(colo)
END SUB

'The ready-made glyphs (PUT) against the runs (LINE): the same text on the same
'background must give the same pixels.
SUB SpriteCase (fg, bg)
FOR pass = 0 TO 1
        gFill 0, 0, 639, 479, bg
        IF pass = 0 THEN CoutBg = -1 ELSE CoutBg = bg
        FOR rw = 0 TO 1
                t$ = ""
                FOR c = 0 TO 47
                        t$ = t$ + CHR$(32 + rw * 48 + c)
                NEXT
                cout t$, 3, rw * 24 + 5, fg, 640, 0
        NEXT
        CoutBg = -1
        IF pass = 0 THEN
                SnapNo = SnapNo + 1
                Dump "A"
        ELSE
                Dump "B"
        END IF
NEXT
Emit "SNAP" + STR$(SnapNo) + " sprites equal runs, colour" + STR$(fg) + " on" + STR$(bg)
END SUB

'Time and count what a run of operations costs.
SUB PerfStart
gWrites = 0
gCalls = 0
gPsets = 0
NoSync = -1
PerfT = TIMER
END SUB

SUB PerfStop (lbl$)
dt! = TIMER - PerfT
NoSync = 0
Metric "speed: " + lbl$ + ": seconds", dt!
Metric "speed: " + lbl$ + ": graphics calls", CSNG(gCalls)
Metric "speed: " + lbl$ + ": single pixels", CSNG(gPsets)
Metric "speed: " + lbl$ + ": pixels written", CSNG(gWrites)
END SUB

'Corrupt a rectangle, repaint it, expect the reference image.
SUB ThinCase (lbl$, x1, y1, x2, y2)
gFill x1, y1, x2, y2, 9
RepaintRect x1, y1, x2, y2
CompareToLegacy lbl$
END SUB

'The heap keeps blocks intact when others are freed, compacts without gaps,
'refuses what does not fit, and gives back everything a closed window owned.
SUB HeapCase
WinReset
a = MemAlloc(1, 10)
b = MemAlloc(2, 20)
c = MemAlloc(1, 5)
FOR i = 0 TO 9: MemSet a, i, 100 + i: NEXT
FOR i = 0 TO 19: MemSet b, i, 200 + i: NEXT
FOR i = 0 TO 4: MemSet c, i, 300 + i: NEXT
Check "heap: three blocks fill 35 words", HeapTop = 35, STR$(HeapTop)
MemFree a
ok = (HeapTop = 25 AND HBase(b) = 0 AND HBase(c) = 20)
FOR i = 0 TO 19
        IF MemGet(b, i) <> 200 + i THEN ok = 0
NEXT
FOR i = 0 TO 4
        IF MemGet(c, i) <> 300 + i THEN ok = 0
NEXT
Check "heap: a free slides the blocks above it down and keeps their data", ok, STR$(HeapTop)
Check "heap: a freed handle reads 0", MemGet(a, 0) = 0, ""
MemSet b, 20, 7
MemSet b, -1, 7
Check "heap: an index outside the block is refused", MemGet(b, 20) = 0 AND MemGet(c, 0) = 300, ""
Check "heap: a block that does not fit is refused", MemAlloc(3, 5000) = 0, ""
MemFreeAll 1
Check "heap: freeing an owner frees all its blocks", HeapTop = 20 AND HSize(c) = 0 AND MemGet(b, 19) = 219, STR$(HeapTop)
d = MemAlloc(4, HeapWords + 1 - 20)
Check "heap: a block can fill the heap to the last word", d > 0 AND MemAlloc(4, 1) = 0, STR$(d)
MemFreeAll 4

'A window made by an app owns a data block; closing it frees block and controls.
Scene 4
w = AppWindow(9, "Data", 400, 300, 100, 60, 8)
used = HeapTop
AppSet w, 3, 77
Check "app window: its data block holds a value", AppGet(w, 3) = 77 AND used = 8, STR$(used)
x = CtlAdd(w, CtlButton, 4, 4, 60, 22, "X")
RepaintRect 0, 0, 639, 479
WinClose w
Check "close: the heap block is freed", HeapTop = 0, STR$(HeapTop)
Check "close: the window left the order", WNumber = 2, STR$(WNumber)
Check "close: its control is dead and its number is reused", CtlAdd(1, CtlLabel, 0, 0, 10, 10, "") = x, ""
CompareToLegacy "close: the area of a closed window is repainted"
WinClose 1
CompareToLegacy "close: a window with controls closes"
Check "close: its controls take no click", CtlAt(150, 66) = 0, STR$(CtlAt(150, 66))
END SUB
