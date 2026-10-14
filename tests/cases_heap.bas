'Cases: the heap, closing windows, running out of memory.
SUB RunAll
HeapCase
OomCase
END SUB

SUB HeapCase
WinReset
a = MemAlloc(1, KData, 10)
b = MemAlloc(2, KData, 20)
c = MemAlloc(1, KData, 5)
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
OomFlag = 0
Check "heap: a block that does not fit is refused", MemAlloc(3, KData, 5000) = 0 AND OomFlag, ""
MemFreeAll 1
Check "heap: freeing an owner frees all its blocks", HeapTop = 20 AND HSize(c) = 0 AND MemGet(b, 19) = 219, STR$(HeapTop)
d = MemAlloc(4, KData, HeapWords + 1 - 20)
Check "heap: a block can fill the heap to the last word", d > 0 AND MemAlloc(4, KData, 1) = 0, STR$(d)
MemFreeAll 4

'A window made by an app owns a data block and controls; closing it frees all.
Scene 4
hb = HeapTop
n = WNumber
w = AppWindow(9, "Data", 400, 300, 100, 60, 8)
AppSet w, 3, 77
Check "app window: its data block holds a value", AppGet(w, 3) = 77 AND HeapTop = hb + WinWords + 8, STR$(HeapTop - hb)
x = CtlAdd(w, CtlButton, 4, 4, 60, 22, "X")
RepaintRect 0, 0, 639, 479
WinClose w
Check "close: window, data and control are freed", HeapTop = hb, STR$(HeapTop - hb)
Check "close: the window left the order", WNumber = n, STR$(WNumber)
Check "close: its handles are reused", CtlAdd(1, CtlLabel, 0, 0, 10, 10, "") = w, ""
CompareToLegacy "close: the area of a closed window is repainted"
WinClose 1
CompareToLegacy "close: a window with controls closes"
Check "close: its controls take no click", CtlAt(150, 66) = 0, STR$(CtlAt(150, 66))
END SUB

'Running out of memory: a refusal and a flag, never a crash, and nothing half
'made is left.
SUB OomCase
'The heap is full: the window made for the block goes again.
WinReset
a = AppWindow(9, "A", 10, 10, 100, 60, HeapWords + 1 - WinWords)
OomFlag = 0
b = AppWindow(9, "B", 50, 50, 100, 60, 5)
Check "oom: no heap, no window", a > 0 AND b = 0 AND OomFlag AND WNumber = 1, STR$(b) + STR$(OomFlag) + STR$(WNumber)
Check "oom: the first window and the full heap are intact", HeapTop = HeapWords + 1, STR$(HeapTop)
'No free handle: windows and controls share them.
WinReset
n = 0
DO
        w = AppWindow(9, "W", n * 5, n * 5, 90, 40, 1)
        IF w > 0 THEN n = n + 1
LOOP WHILE w > 0 AND n < 100
Check "oom: windows stop at the last handle, with a flag", n > 8 AND n < 100 AND OomFlag AND WNumber = n, STR$(n)
used = 0
FOR i = 1 TO HeapMax
        IF HSize(i) > 0 THEN used = used + 1
NEXT
Check "oom: all handles but at most one are in use", used >= HeapMax - 1, STR$(used)
WinReset
w = AppWindow(9, "C", 10, 10, 200, 200, 1)
n = 0
DO
        id = CtlAdd(w, CtlLabel, 0, 0, 10, 10, "")
        IF id > 0 THEN n = n + 1
LOOP WHILE id > 0 AND n < 100
Check "oom: controls stop at the last handle", n > 20 AND n < 100, STR$(n)
OomFlag = 0
Check "oom: a control of window 0 is refused quietly", CtlAdd(0, CtlLabel, 0, 0, 10, 10, "") = 0 AND OomFlag = 0, ""
'An app that cannot get its memory leaves nothing behind.
WinReset
a = AppWindow(9, "Fill", 10, 10, 100, 60, HeapWords + 1 - WinWords - 3)
n = WNumber: tp = HeapTop
AppLaunch 1
Check "oom launch: heap full, no window left", WNumber = n AND HeapTop = tp AND OomFlag, STR$(WNumber) + STR$(HeapTop)
WinReset
FOR i = 1 TO HeapMax - 2
        dummy = MemAlloc(1, KData, 1)
NEXT
n = WNumber: tp = HeapTop
AppLaunch 1
Check "oom launch: no handle for the controls, the half made instance is closed", WNumber = n AND HeapTop = tp AND OomFlag, STR$(WNumber) + STR$(HeapTop)
WinReset
END SUB
