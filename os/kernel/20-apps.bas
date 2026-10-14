'The app interface: windows and data blocks for an app, launching, the dispatch the
'builder generates (at '@@APPS-HERE).

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

'@if blocks
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
'@endif

'Repaint the client area of a window after the app changed what it shows.
'@api Windows | Repaint the client area of a window after the app changed what it shows.
SUB WinInvalidate (who)
WinRect who, x1, y1, x2, y2
RepaintOwn who, x1, y1 + TtlHeight + 1, x2, y2
END SUB

'@if dirty
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
'@endif

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
