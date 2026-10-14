'@app id=2 name=Clock start=ClockStart timer=ClockTimer
'Clock: the date and the time of the system clock, once a second. The timer
'callback sets the next one for the start of the next second, so the display
'does not drift. Data words: the two label numbers.
CONST ClockDate = 0, ClockTime = 1

'The date as 1999-12-31 (DATE$ is month-day-year).
FUNCTION ClockDay$
d$ = DATE$
ClockDay$ = MID$(d$, 7, 4) + "-" + LEFT$(d$, 2) + "-" + MID$(d$, 4, 2)
END FUNCTION

SUB ClockStart
n = (WNumber MOD 6) * 24
w = AppWindow(AppIdClock, "Clock", 420 + n, 40 + n, 170, 80, 2)
AppSet w, ClockDate, CtlAdd(w, CtlLabel, 8, 6, 140, 16, ClockDay$)
AppSet w, ClockTime, CtlAdd(w, CtlLabel, 8, 30, 140, 16, TIME$)
TimerSet AppIdClock, w, 1, 1 - (TIMER - INT(TIMER)) + .01
END SUB

SUB ClockTimer (w, tag)
t$ = TIME$
IF CtlGetText$(AppGet(w, ClockTime)) <> t$ THEN CtlSetText AppGet(w, ClockTime), t$
d$ = ClockDay$
IF CtlGetText$(AppGet(w, ClockDate)) <> d$ THEN CtlSetText AppGet(w, ClockDate), d$
TimerSet AppIdClock, w, 1, 1 - (TIMER - INT(TIMER)) + .01
END SUB
