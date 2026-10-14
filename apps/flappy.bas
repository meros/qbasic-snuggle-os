'@app id=5 name=Flappy start=FlappyStart paint=FlappyPaint key=FlappyKey timer=FlappyTimer opaque uses=immediate,dirty,timers
'Flappy: press Space (or the Flap button) to flap, fly through the gaps. A tick
'every 1/18 s moves the pipes 3 pixels left and pulls the bird down. The window
'is painted from its state (FlappyPaint, immediate mode, opaque), and a tick marks
'only what changed: the bird, and the 3 pixel strips where a pipe left and came.
'Data words: bird height and speed (quarter pixels), three pipes (x, then gap
'top), the score, the state (0 ready, 1 flying, 2 crashed) and the best score.
CONST FlY = 0, FlVy = 1, FlPx = 2, FlGap = 5, FlScore = 8, FlState = 9, FlBest = 10, FlWords = 11
CONST FlW = 240, FlH = 300, FlBirdX = 60, FlPipeW = 30, FlGapH = 84, FlSpace = 120, FlGround = 12

SUB FlappyStart
w = AppWindow(AppIdFlappy, "Flappy", 200, 30, FlW + 6, FlH + 61, FlWords)
RANDOMIZE TIMER
FlappyReset w
END SUB

'Back to the start: the bird in the middle, pipes off to the right.
SUB FlappyReset (w)
AppSet w, FlY, 140 * 4
AppSet w, FlVy, 0
FOR i = 0 TO 2
        AppSet w, FlPx + i, FlW + 20 + i * FlSpace
        AppSet w, FlGap + i, 30 + INT(RND * (FlH - FlGround - FlGapH - 60))
NEXT
AppSet w, FlScore, 0
AppSet w, FlState, 0
END SUB

SUB FlappyPaint (w)
UiFill 0, 0, UiW, FlH, 11
UiFill 0, FlH, UiW, UiH - FlH, 15
FOR i = 0 TO 2
        px = AppGet(w, FlPx + i)
        gy = AppGet(w, FlGap + i)
        UiFill px, 0, FlPipeW, gy, 10
        UiFill px, gy + FlGapH, FlPipeW, FlH - FlGround - gy - FlGapH, 10
NEXT
UiFill 0, FlH - FlGround, UiW, FlGround, 8
by = AppGet(w, FlY) \ 4
UiFill FlBirdX, by, 16, 12, 14
UiFill FlBirdX + 10, by + 2, 3, 3, 0
UiFill FlBirdX + 14, by + 5, 4, 3, 12
state = AppGet(w, FlState)
IF state = 0 THEN UiFill 40, 110, 160, 20, 15: UiLabel 48, 112, 144, 16, "Space to start"
IF state = 2 THEN UiFill 40, 110, 160, 20, 15: UiLabel 48, 112, 144, 16, "Crashed: Space"
UiLabel 4, FlH + 6, 150, 16, "Score" + STR$(AppGet(w, FlScore)) + "  Best" + STR$(AppGet(w, FlBest))
IF UiButton(1, FlW - 70, FlH + 4, 66, 26, "Flap") THEN FlappyFlap w
END SUB

SUB FlappyKey (w, k$)
IF k$ = " " THEN FlappyFlap w
END SUB

'A flap: starts a round, restarts after a crash, or lifts the bird.
SUB FlappyFlap (w)
SELECT CASE AppGet(w, FlState)
CASE 0
        AppSet w, FlState, 1
        AppSet w, FlVy, -14
        TimerSet AppIdFlappy, w, 1, .05
        WinInvalidate w
CASE 1
        AppSet w, FlVy, -14
CASE ELSE
        FlappyReset w
        WinInvalidate w
END SELECT
END SUB

'One tick of the game.
SUB FlappyTimer (w, tag)
IF AppGet(w, FlState) <> 1 THEN EXIT SUB
oldy = AppGet(w, FlY) \ 4
oldscore = AppGet(w, FlScore)
vy = AppGet(w, FlVy) + 1
y = AppGet(w, FlY) + vy
AppSet w, FlVy, vy
AppSet w, FlY, y
by = y \ 4
dead = (by < 0 OR by + 12 > FlH - FlGround)
mx = 0
FOR i = 0 TO 2
        IF AppGet(w, FlPx + i) > mx THEN mx = AppGet(w, FlPx + i)
NEXT
'the bird: where it was and where it is now
IF oldy < by THEN top = oldy ELSE top = by
WinDirty w, FlBirdX, top, 20, ABS(by - oldy) + 13
FOR i = 0 TO 2
        old = AppGet(w, FlPx + i)
        px = old - 3
        gy = AppGet(w, FlGap + i)
        IF px < -FlPipeW THEN
                px = mx + FlSpace
                gy = 30 + INT(RND * (FlH - FlGround - FlGapH - 60))
                AppSet w, FlGap + i, gy
                mx = px
                WinDirty w, old, 0, FlPipeW, FlH
                WinDirty w, px, 0, FlPipeW, FlH
        ELSE
                WinDirty w, old + FlPipeW - 3, 0, 3, FlH
                WinDirty w, px, 0, 3, FlH
        END IF
        AppSet w, FlPx + i, px
        IF px + FlPipeW < FlBirdX AND px + FlPipeW + 3 >= FlBirdX THEN AppSet w, FlScore, AppGet(w, FlScore) + 1
        IF FlBirdX + 16 > px AND FlBirdX < px + FlPipeW THEN
                IF by < gy OR by + 12 > gy + FlGapH THEN dead = -1
        END IF
NEXT
IF AppGet(w, FlScore) <> oldscore THEN WinDirty w, 0, FlH, FlW, 40
IF dead THEN
        AppSet w, FlState, 2
        IF AppGet(w, FlScore) > AppGet(w, FlBest) THEN AppSet w, FlBest, AppGet(w, FlScore)
        WinDirty w, 0, 0, FlW + 1, FlH + 40
END IF
WinFlush
IF NOT dead THEN TimerSet AppIdFlappy, w, 1, .05
END SUB
