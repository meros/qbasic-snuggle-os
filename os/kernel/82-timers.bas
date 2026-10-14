'Part timers: callbacks on the system clock.

'@if timers
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
                                Repaint 0, 0, 639, 15
                        ELSE
                                AppTimer TmApp(i), TmWin(i), TmTag(i)
                        END IF
                END IF
        END IF
NEXT
END SUB
'Drop the timers of a window that closes.
SUB TimersDrop (who)
FOR i = 1 TO TimerMax
        IF TmWin(i) = who AND TmApp(i) > 0 THEN TmUsed(i) = 0
NEXT
END SUB
'@else
SUB TimerSet (app, win, tag, secs!)
END SUB

SUB TimersRun
END SUB

SUB TimersDrop (who)
END SUB
'@endif
