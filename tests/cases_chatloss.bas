'Cases: Chat when the relay is not there, and when it goes away and comes back
'(scripts/test-chat.sh starts and stops it when this program makes a file:
'START.TXT, STOP.TXT, START2.TXT).
SUB RunAll
NoSync = -1
WinReset
AppLaunch AppIdChat
w = WNew
BlockSetText AppGet(w, ChName), "dave"
'there is no relay yet
t! = TIMER
DO
        ChatTimer w, 1
LOOP WHILE ABS(TIMER - t!) < 9
Check "loss: with no relay the state is disconnected", AppGet(w, ChState) = 0, STR$(AppGet(w, ChState))
ChatCommand w, "this goes nowhere"
Check "loss: a message while down is refused", LogHas(w, "! not connected"), ""
MakeFile "START.TXT"
WaitState w, 2, 40
Check "loss: a relay that comes up later is found", AppGet(w, ChState) = 2, STR$(AppGet(w, ChState))
MakeFile "STOP.TXT"
WaitState w, 0, 30
Check "loss: no heartbeat for six seconds is a lost relay", AppGet(w, ChState) = 0, STR$(AppGet(w, ChState))
Check "loss: the log says so", LogHas(w, "* no relay: disconnected"), ""
MakeFile "START2.TXT"
WaitState w, 2, 40
Check "loss: when the relay is back the OS connects again", AppGet(w, ChState) = 2, STR$(AppGet(w, ChState))
Emit "DONE tests=" + STR$(TestCount) + " fails=" + STR$(TestFails)
SYSTEM
END SUB

'Tell the script what to do by making a file.
SUB MakeFile (f$)
OPEN f$ FOR OUTPUT AS #7
PRINT #7, "x"
CLOSE #7
END SUB

SUB WaitState (w, st, secs)
t! = TIMER
DO
        ChatTimer w, 1
        IF AppGet(w, ChState) = st THEN EXIT DO
LOOP WHILE ABS(TIMER - t!) < secs
END SUB

FUNCTION LogHas (w, t$)
LogHas = 0
FOR i = 0 TO ChLines - 1
        IF LEFT$(BlockText$(AppGet(w, ChLine + i)), LEN(t$)) = t$ THEN LogHas = -1
NEXT
END FUNCTION
