'Cases: the heap, closing windows, running out of memory.
SUB RunAll
HeapCase
OomCase
TimerCase
ClockCase
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

'A notice leaves the bar when its time is up, and a closed window's timers go.
SUB TimerCase
Scene 1
RepaintRect 0, 0, 639, 479
Notice "Out of memory. The app was not started."
Check "timer: the notice sets a kernel timer", TmUsed(1) AND TmApp(1) = 0, ""
TimersRun
Check "timer: not yet due", TmUsed(1) <> 0, ""
TimerSet 0, 0, 1, 0
TimersRun
Check "timer: when due it runs once", TmUsed(1) = 0, ""
CompareToLegacy "timer: the bar is repainted away"
w = AppWindow(1, "Hello", 170, 100, 300, 240, 7)
AppSet w, HelloMsg, CtlAdd(w, CtlLabel, 8, 178, 262, 16, "Hello, x")
TimerSet 1, w, 1, 0
TimersRun
Check "timer: an app callback ran", CtlGetText$(AppGet(w, HelloMsg)) = "Ready", CtlGetText$(AppGet(w, HelloMsg))
TimerSet 1, w, 1, 100
TimerSet 1, w, 1, 100
used = 0
FOR i = 1 TO 8
        IF TmUsed(i) THEN used = used + 1
NEXT
Check "timer: the same timer set again is one timer", used = 1, STR$(used)
WinClose w
used = 0
FOR i = 1 TO 8
        IF TmUsed(i) THEN used = used + 1
NEXT
Check "timer: closing a window drops its timers", used = 0, STR$(used)
END SUB

'The clock app: one window with the date and the time, kept up by its timer.
SUB ClockCase
Scene 1
RepaintRect 0, 0, 639, 479
n = WNumber
AppLaunch AppIdClock
w = WNew
Check "clock: a launch makes one window", WNumber = n + 1 AND HKind(w) = KWin AND HGet(w, WfApp) = AppIdClock, STR$(WNumber)
t$ = CtlGetText$(AppGet(w, ClockTime))
Check "clock: it shows a time, hh:mm:ss", LEN(t$) = 8 AND MID$(t$, 3, 1) = ":" AND MID$(t$, 6, 1) = ":", t$
d$ = CtlGetText$(AppGet(w, ClockDate))
Check "clock: it shows a date, yyyy-mm-dd", LEN(d$) = 10 AND MID$(d$, 5, 1) = "-" AND MID$(d$, 8, 1) = "-", d$
armed = 0
FOR i = 1 TO 16
        IF TmUsed(i) AND TmApp(i) = AppIdClock AND TmWin(i) = w THEN armed = armed + 1
NEXT
Check "clock: one timer is armed for it", armed = 1, STR$(armed)
CtlSetText AppGet(w, ClockTime), "00:00:00"
TimerSet AppIdClock, w, 1, 0
TimersRun
t$ = CtlGetText$(AppGet(w, ClockTime))
Check "clock: the callback sets the time again", LEN(t$) = 8 AND t$ <> "00:00:00", t$
armed = 0
FOR i = 1 TO 16
        IF TmUsed(i) AND TmApp(i) = AppIdClock AND TmWin(i) = w THEN armed = armed + 1
NEXT
Check "clock: and arms the next tick", armed = 1, STR$(armed)
CompareToLegacy "clock: the window is painted and updated"
'A control that hangs over the screen edge can be redrawn (it did raise error 5).
WinMoveTo w, 600, 100
CtlSetText AppGet(w, ClockTime), "11:11:11"
CompareToLegacy "clock: a label partly off screen changes text"
WinClose w
armed = 0
FOR i = 1 TO 16
        IF TmUsed(i) THEN armed = armed + 1
NEXT
Check "clock: closing it drops the timer", armed = 0, STR$(armed)
END SUB
