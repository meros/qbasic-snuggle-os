'One pass of the main loop.

'One pass of the main loop: a click on a window or the desktop (it runs until
'the button goes up), a key, a control event, the timers. The tests call it
'with a scripted mouse.
SUB MainStep
IF mouse.getbutton = LB THEN
mouse.getpos cmx, cmy
hit = 0
FOR Cyc = 1 TO WNumber
IF hit <> 0 THEN EXIT FOR
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
