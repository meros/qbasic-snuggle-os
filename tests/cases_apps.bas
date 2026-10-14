'Cases: the apps (Clock, Calc, Flappy) driven through their own procedures.
SUB RunAll
ClockCase
CalcCase
FlappyCase
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

'Press the calculator keys in k$ one after another (as immediate mode button
'clicks, by id: 1 to 16 and 17 for C) and return the display.
FUNCTION CalcKeys$ (w, k$)
keys$ = "789/456*123-0.=+"
FOR j = 1 TO LEN(k$)
        ch$ = MID$(k$, j, 1)
        IF ch$ = "C" THEN id = 17 ELSE id = INSTR(keys$, ch$)
        UiFire w, id
NEXT
CalcKeys$ = CtlGetText$(AppGet(w, CalcDisp))
END FUNCTION

'The calculator: arithmetic through its immediate mode keys, and its window.
SUB CalcCase
NoSync = -1
Scene 1
RepaintRect 0, 0, 639, 479
AppLaunch AppIdCalc
w = WNew
owned = 0
FOR h = 1 TO HeapMax
        IF HSize(h) > 0 AND HOwner(h) = w THEN owned = owned + 1
NEXT
Check "calc: 17 keys take no heap: window, data and display only", owned = 3, STR$(owned)
CompareToLegacy "calc: the window with its keys"
'Which key is under a point: the grid, C, and the gap between keys.
WinRect w, wx1, wy1, wx2, wy2
ox = wx1 + 3
oy = wy1 + TtlHeight + 4
Check "calc: nothing is held, so no key looks pressed", POINT(ox + 9, oy + 33) = 15, STR$(POINT(ox + 9, oy + 33))
UiMx = ox + 8 + 5: UiMy = oy + 32 + 5: UiHitId = 0: UiRun w, 1
Check "calc: the point over 7 finds button 1", UiHitId = 1 AND UiHx1 = ox + 8, STR$(UiHitId)
UiMx = ox + 8 + 44 * 3 + 5: UiMy = oy + 32 + 34 * 3 + 5: UiHitId = -1: UiRun w, 1
Check "calc: the point over + finds button 16", UiHitId = 16, STR$(UiHitId)
UiMx = ox + 10: UiMy = oy + 168 + 5: UiHitId = -1: UiRun w, 1
Check "calc: the point over C finds button 17", UiHitId = 17, STR$(UiHitId)
UiMx = ox + 8 + 40 + 2: UiMy = oy + 32 + 5: UiHitId = -1: UiRun w, 1
Check "calc: the gap between keys finds none", UiHitId = -1, STR$(UiHitId)
Check "calc: 12 + 7 =", CalcKeys$(w, "12+7=") = "19", CalcKeys$(w, "")
Check "calc: 9 / 0 is an error", CalcKeys$(w, "C9/0=") = "Error", CalcKeys$(w, "")
Check "calc: C clears it", CalcKeys$(w, "C") = "0", CalcKeys$(w, "")
Check "calc: 1.5 * 2 =", CalcKeys$(w, "1.5*2=") = "3", CalcKeys$(w, "")
Check "calc: 5 + 3 + shows 8", CalcKeys$(w, "C5+3+") = "8", CalcKeys$(w, "")
Check "calc: ... and 2 = is 10", CalcKeys$(w, "2=") = "10", CalcKeys$(w, "")
Check "calc: a leading zero goes", CalcKeys$(w, "C007") = "7", CalcKeys$(w, "")
Check "calc: a second point is ignored", CalcKeys$(w, "C1..5") = "1.5", CalcKeys$(w, "")
Check "calc: a point first is 0.", CalcKeys$(w, "C.5") = "0.5", CalcKeys$(w, "")
Check "calc: 0.5 - 2 =", CalcKeys$(w, "-2=") = "-1.5", CalcKeys$(w, "")
Check "calc: a new number after = starts fresh", CalcKeys$(w, "C8=6") = "6", CalcKeys$(w, "")
Check "calc: an operator after = goes on with the result", CalcKeys$(w, "C4*5=+1=") = "21", CalcKeys$(w, "")
Check "calc: a number too long to show is an error", CalcKeys$(w, "C9999999999*9999999999=") = "Error", CalcKeys$(w, "")
dummy$ = CalcKeys$(w, "C2*8")
CompareToLegacy "calc: the window after some keys"
WinClose w
NoSync = 0
END SUB

'The game: physics, pipes, score, a crash and a restart, then its window.
SUB FlappyCase
NoSync = -1
Scene 1
RepaintRect 0, 0, 639, 479
AppLaunch AppIdFlappy
w = WNew
Check "flappy: a launch makes a window, ready to start", HKind(w) = KWin AND AppGet(w, FlState) = 0, STR$(AppGet(w, FlState))
FlappyKey w, "x"
Check "flappy: other keys do nothing", AppGet(w, FlState) = 0, ""
FlappyKey w, " "
Check "flappy: space starts the round with a flap", AppGet(w, FlState) = 1 AND AppGet(w, FlVy) = -14, STR$(AppGet(w, FlState))
y0 = AppGet(w, FlY)
FlappyTimer w, 1
Check "flappy: a tick moves the bird by its speed and pulls it down", AppGet(w, FlY) = y0 - 13 AND AppGet(w, FlVy) = -13, STR$(AppGet(w, FlY) - y0)
p0 = AppGet(w, FlPx)
FlappyTimer w, 1
Check "flappy: the pipes move 3 pixels a tick", AppGet(w, FlPx) = p0 - 3, STR$(AppGet(w, FlPx) - p0)
armed = 0
FOR i = 1 TO TimerMax
        IF TmUsed(i) AND TmApp(i) = AppIdFlappy AND TmWin(i) = w THEN armed = armed + 1
NEXT
Check "flappy: the next tick is armed", armed = 1, STR$(armed)
'A pipe the bird has just passed counts once: the gap is around the bird.
AppSet w, FlGap, 100
AppSet w, FlPx, FlBirdX - FlPipeW + 1
AppSet w, FlY, 135 * 4
AppSet w, FlVy, 0
sc = AppGet(w, FlScore)
FlappyTimer w, 1
Check "flappy: passing a pipe scores 1 and the bird lives", AppGet(w, FlScore) = sc + 1 AND AppGet(w, FlState) = 1, STR$(AppGet(w, FlScore)) + STR$(AppGet(w, FlState))
'A pipe in the bird's way ends the round.
AppSet w, FlGap, 200
AppSet w, FlPx, FlBirdX - 5
AppSet w, FlY, 140 * 4
AppSet w, FlVy, 0
FlappyTimer w, 1
Check "flappy: a pipe in the way crashes the bird", AppGet(w, FlState) = 2 AND AppGet(w, FlBest) = AppGet(w, FlScore), STR$(AppGet(w, FlState))
CompareToLegacy "flappy: the crashed window"
FlappyKey w, " "
Check "flappy: space after a crash starts over", AppGet(w, FlState) = 0 AND AppGet(w, FlScore) = 0, STR$(AppGet(w, FlState))
'No flap: the bird falls to the ground and the round ends.
FlappyKey w, " "
n = 0
DO WHILE AppGet(w, FlState) = 1 AND n < 300
        FlappyTimer w, 1
        n = n + 1
LOOP
Check "flappy: a bird that is not flapped crashes", AppGet(w, FlState) = 2 AND n < 300, STR$(n)
FlappyReset w
FlappyKey w, " "
FOR i = 1 TO 6
        FlappyTimer w, 1
NEXT
CompareToLegacy "flappy: the window after ticks that repaint only what changed"
'A flap tick marks little: far fewer pixels than the whole window.
gWrites = 0
FlappyTimer w, 1
tickW& = gWrites
Metric "flappy tick writes", CSNG(tickW&)
gWrites = 0
WinInvalidate w
Metric "flappy full repaint writes", CSNG(gWrites)
Check "flappy: a tick writes under a tenth of a full repaint", tickW& * 10 < gWrites, STR$(tickW&) + STR$(gWrites)
CompareToLegacy "flappy: the window during a round"
'A window in front is not erased and drawn again when the game behind it moves.
AppLaunch AppIdCalc
cw = WNew
WinRect w, fx1, fy1, fx2, fy2
WinMoveTo cw, fx1 + 20, fy1 + 60
FlappyTimer w, 1
gWrites = 0
FlappyTimer w, 1
behindW& = gWrites
Metric "flappy tick behind calc writes", CSNG(behindW&)
Check "flappy: a tick behind another window repaints none of it", behindW& <= tickW& + 100, STR$(behindW&) + STR$(tickW&)
CompareToLegacy "flappy: the game behind the calculator"
WinClose cw
WinClose w
NoSync = 0
END SUB
