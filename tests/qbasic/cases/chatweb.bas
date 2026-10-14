'Cases: Chat with the lines in files (SNUGGLE=web), as the browser page carries
'them (the runner sets SNUGGLE=web). The test plays the page: it appends to
'CHATIN.TXT and reads CHATOUT.TXT.
SUB RunAll
NoSync = -1
WinReset
OPEN "CHATIN.TXT" FOR OUTPUT AS #8
CLOSE #8
OPEN "CHATOUT.TXT" FOR OUTPUT AS #8
CLOSE #8
AppLaunch AppIdChat
w = WNew
Check "chatweb: a launch makes the window", HKind(w) = KWin AND ChatWeb = -1, STR$(w)
BlockSetText AppGet(w, ChName), "erin"
Check "chatweb: no heartbeat yet, disconnected", AppGet(w, ChState) = 0, STR$(AppGet(w, ChState))
ChatCommand w, "too early"
Check "chatweb: a message while down is refused", LogHas(w, "! not connected"), ""
Page "HB UP"
Pump w
Check "chatweb: a heartbeat from the page connects", AppGet(w, ChState) = 2, STR$(AppGet(w, ChState))
Check "chatweb: connecting sends the name and the room", OutHas("NAME erin") AND OutHas("JOIN lobby"), ""
ChatCommand w, "hello room"
Check "chatweb: a message goes to CHATOUT.TXT", OutHas("MSG lobby hello room"), ""
Page "MSG lobby bob hi erin"
Pump w
Check "chatweb: a line from the page shows in the log", LogHas(w, "<bob> hi erin"), ""
'a line that arrives in two pieces
Page2 "MSG lobby bob spl"
Pump w
Page "it"
Pump w
Check "chatweb: a line in two pieces is joined", LogHas(w, "<bob> split"), ""
'more than 128 characters in one go
FOR i = 1 TO 12
        Page "MSG lobby bob line" + STR$(i) + " filler filler filler"
NEXT
FOR i = 1 TO 6
        Pump w
NEXT
Check "chatweb: a burst is read in several steps", LogHas(w, "<bob> line 12 filler filler filler"), ""
Emit "DONE tests=" + STR$(TestCount) + " fails=" + STR$(TestFails)
SYSTEM
END SUB

'A whole line from the page.
SUB Page (t$)
Page2 t$ + CHR$(13) + CHR$(10)
END SUB

'Text from the page, appended to CHATIN.TXT.
SUB Page2 (t$)
f = FREEFILE
OPEN "CHATIN.TXT" FOR BINARY AS #f
SEEK #f, LOF(f) + 1
PUT #f, , t$
CLOSE #f
END SUB

SUB Pump (w)
ChatTimer w, 1
END SUB

FUNCTION OutHas (t$)
OutHas = 0
f = FREEFILE
OPEN "CHATOUT.TXT" FOR INPUT AS #f
DO WHILE NOT EOF(f)
        LINE INPUT #f, l$
        IF l$ = t$ THEN OutHas = -1
LOOP
CLOSE #f
END FUNCTION

FUNCTION LogHas (w, t$)
LogHas = 0
FOR i = 0 TO ChLines - 1
        IF LEFT$(BlockText$(AppGet(w, ChLine + i)), LEN(t$)) = t$ THEN LogHas = -1
NEXT
END FUNCTION
