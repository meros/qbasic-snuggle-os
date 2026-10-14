'Cases: Chat through the real serial port, the relay and the server (the peer
'bob is a script, scripts/test-chat.sh).
SUB RunAll
NoSync = -1
WinReset
AppLaunch AppIdChat
w = WNew
Check "chat: a launch makes the window", HKind(w) = KWin AND ChatWin = w, STR$(w)
BlockSetText AppGet(w, ChName), "carol"
WaitState w, 2, 20
Check "chat: it connects through the relay to the server", AppGet(w, ChState) = 2, STR$(AppGet(w, ChState))
WaitLog w, "* carol joined lobby", 10
Check "chat: joining the room shows", LogHas(w, "* carol joined lobby"), ""
ChatCommand w, "hello room"
WaitLog w, "<carol> hello room", 10
Check "chat: a message comes back from the server to the room", LogHas(w, "<carol> hello room"), ""
WaitLog w, "<bob> hello from bob", 15
Check "chat: a message from another user shows", LogHas(w, "<bob> hello from bob"), ""
WaitLog w, "*bob* psst", 10
Check "chat: a direct message shows", LogHas(w, "*bob* psst"), ""
ChatCommand w, "/dm bob thanks"
WaitLog w, "-> bob: thanks", 10
Check "chat: a direct message sent is confirmed", LogHas(w, "-> bob: thanks"), ""
ChatCommand w, "/who"
WaitLog w, "users: ", 10
Check "chat: /who lists the room", LogHas(w, "users: bob carol") OR LogHas(w, "users: carol bob"), ""
ChatCommand w, "/join den"
WaitLog w, "* carol joined den", 10
Check "chat: /join changes the room", LogHas(w, "* carol joined den") AND BlockText$(AppGet(w, ChRoom)) = "den", BlockText$(AppGet(w, ChRoom))
ChatCommand w, "/dm nobody hi"
WaitLog w, "! no such user", 10
Check "chat: an error from the server shows", LogHas(w, "! no such user"), ""
WinSetState w, 2
RepaintRect 0, 0, 639, 479
CtlRect AppGet(w, ChInput), ix1, iy1, ix2, iy2
WinGeom w, wx, wy, ww, wh, wst
Check "chat: maximised, the input box sits at the bottom and spans the width", iy2 >= wy + wh - 10 AND ix2 - ix1 >= ww - 16, STR$(iy2) + STR$(wy + wh) + STR$(ix2 - ix1)
CompareToLegacy "look: chat maximised"
WinSetState w, 1
RepaintRect 0, 0, 639, 479
CtlRect AppGet(w, ChInput), ix1, iy1, ix2, iy2
WinGeom w, wx, wy, ww, wh, wst
Check "chat: restored, the input box follows the window again", iy2 >= wy + wh - 10 AND ix2 - ix1 >= ww - 16 AND ix2 - ix1 < 400, STR$(iy2) + STR$(wy + wh) + STR$(ix2 - ix1)
Emit "DONE tests=" + STR$(TestCount) + " fails=" + STR$(TestFails)
SYSTEM
END SUB

'Poll the port until the connection state is st, at most secs seconds.
SUB WaitState (w, st, secs)
t! = TIMER
DO
        ChatTimer w, 1
        IF AppGet(w, ChState) = st THEN EXIT DO
LOOP WHILE ABS(TIMER - t!) < secs
END SUB

'Poll the port until the log has a line that starts with t$.
SUB WaitLog (w, t$, secs)
t! = TIMER
DO
        ChatTimer w, 1
        IF LogHas(w, t$) THEN EXIT DO
LOOP WHILE ABS(TIMER - t!) < secs
END SUB

FUNCTION LogHas (w, t$)
LogHas = 0
FOR i = 0 TO ChLines - 1
        IF LEFT$(BlockText$(AppGet(w, ChLine + i)), LEN(t$)) = t$ THEN LogHas = -1
NEXT
END FUNCTION
