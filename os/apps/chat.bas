'@app id=6 name=Chat start=ChatStart event=ChatEvent paint=ChatPaint timer=ChatTimer uses=controls,immediate,timers,blocks
'Chat: names, rooms and direct messages through the host relay, over the serial
'port COM1 (docs/CHAT.md has the protocol). Text goes to the room you are in;
'/name x, /join room, /dm user text and /who are commands. One window only (the
'port is one). The relay sends HB UP or HB DOWN every two seconds: when none comes for six the
'status says Disconnected, and when the relay comes back the name and the room
'are taken again.
'Data words: the input box, 12 log lines (blocks), name, room, receive buffer
'(blocks), the connection state (0 no relay, 1 relay but no server, 2 up) and the
'time of the last line from the relay (seconds, modulo 30000).
'In a browser there is no serial port: the host page (docs/WEB.md) carries the
'lines in two files instead, CHATOUT.TXT (appended here) and CHATIN.TXT (appended
'by the page), when the environment variable SNUGGLE is web. ChOff and the word
'after it are the bytes of CHATIN.TXT read so far.
CONST ChInput = 0, ChLine = 1, ChName = 13, ChRoom = 14, ChRx = 15, ChState = 16, ChHb = 17, ChOff = 18, ChWords = 20, ChLines = 12
DIM SHARED ChatPort AS INTEGER
DIM SHARED ChatWeb AS INTEGER
DIM SHARED ChatWin AS INTEGER

SUB ChatStart
IF ChatWin > 0 THEN
        IF HKind(ChatWin) = KWin THEN
                IF HGet(ChatWin, WfApp) = AppIdChat THEN
                        WinPutTop ChatWin
                        EXIT SUB
                END IF
        END IF
END IF
w = AppWindow(AppIdChat, "Chat", 120, 40, 336, 285, ChWords)
IF w = 0 THEN EXIT SUB
ChatWin = w
FOR i = 0 TO ChLines - 1
        AppSet w, ChLine + i, AppBlock(w)
NEXT
AppSet w, ChName, AppBlock(w)
AppSet w, ChRoom, AppBlock(w)
AppSet w, ChRx, AppBlock(w)
BlockSetText AppGet(w, ChName), "guest" + LTRIM$(STR$(INT(TIMER) MOD 90 + 10))
BlockSetText AppGet(w, ChRoom), "lobby"
AppSet w, ChInput, CtlAdd(w, CtlText, 4, 230, 322, 24, "")
ChatWeb = (ENVIRON$("SNUGGLE") = "web")
IF ChatWeb = 0 AND ChatPort = 0 THEN
        ChatPort = FREEFILE
        OPEN "COM1:9600,N,8,1,CS0,DS0,CD0,RS" FOR RANDOM AS #ChatPort
END IF
AppSet w, ChHb, INT(TIMER) MOD 30000
AppSet w, ChState, 0
IF ChatWeb THEN
        'start at the end: lines of an earlier instance are not shown again
        f = FREEFILE
        OPEN "CHATIN.TXT" FOR BINARY AS #f
        rd& = LOF(f)
        CLOSE #f
        AppSet w, ChOff, rd& AND 16383
        AppSet w, ChOff + 1, rd& \ 16384
END IF
ChatLog w, "* waiting for the relay"
TimerSet AppIdChat, w, 1, .1
END SUB

'The nth word of a line (1 is the first), "" when there is none.
FUNCTION ChatWord$ (s$, n)
p = 1
FOR i = 1 TO n
        DO WHILE MID$(s$, p, 1) = " " AND p <= LEN(s$)
                p = p + 1
        LOOP
        IF i = n THEN EXIT FOR
        q = INSTR(p, s$, " ")
        IF q = 0 THEN
                ChatWord$ = ""
                EXIT FUNCTION
        END IF
        p = q
NEXT
q = INSTR(p, s$, " ")
IF q = 0 THEN ChatWord$ = MID$(s$, p) ELSE ChatWord$ = MID$(s$, p, q - p)
END FUNCTION

'What is left of a line after its first n words.
FUNCTION ChatRest$ (s$, n)
p = 1
FOR i = 1 TO n
        DO WHILE MID$(s$, p, 1) = " " AND p <= LEN(s$)
                p = p + 1
        LOOP
        q = INSTR(p, s$, " ")
        IF q = 0 THEN
                ChatRest$ = ""
                EXIT FUNCTION
        END IF
        p = q
NEXT
ChatRest$ = LTRIM$(MID$(s$, p))
END FUNCTION

'A line for the log: the others go up one.
SUB ChatLog (w, t$)
FOR i = 0 TO ChLines - 2
        BlockSetText AppGet(w, ChLine + i), BlockText$(AppGet(w, ChLine + i + 1))
NEXT
BlockSetText AppGet(w, ChLine + ChLines - 1), LEFT$(t$, 64)
WinInvalidate w
END SUB

'A line to the relay. PRINT to a COM file opened FOR RANDOM sends the text
'without a line end, so the line feed is added here.
SUB ChatSend (t$)
IF ChatWeb THEN
        f = FREEFILE
        OPEN "CHATOUT.TXT" FOR APPEND AS #f
        PRINT #f, t$
        CLOSE #f
ELSE
        PRINT #ChatPort, t$ + CHR$(10);
END IF
END SUB

'What came in since the last look, at most 128 characters: from the serial
'port, or from the end of what was read of CHATIN.TXT.
FUNCTION ChatRecv$ (w)
ChatRecv$ = ""
IF ChatWeb THEN
        f = FREEFILE
        OPEN "CHATIN.TXT" FOR BINARY AS #f
        rd& = AppGet(w, ChOff + 1) * 16384& + AppGet(w, ChOff)
        n& = LOF(f) - rd&
        IF n& > 128 THEN n& = 128
        IF n& > 0 THEN
                SEEK #f, rd& + 1
                ChatRecv$ = INPUT$(n&, #f)
                rd& = rd& + n&
                AppSet w, ChOff, rd& AND 16383
                AppSet w, ChOff + 1, rd& \ 16384
        END IF
        CLOSE #f
ELSE
        n = LOC(ChatPort)
        IF n > 128 THEN n = 128
        IF n > 0 THEN ChatRecv$ = INPUT$(n, #ChatPort)
END IF
END FUNCTION

SUB ChatState (w, st)
IF AppGet(w, ChState) = st THEN EXIT SUB
AppSet w, ChState, st
SELECT CASE st
CASE 0
        ChatLog w, "* no relay: disconnected"
CASE 1
        ChatLog w, "* relay up, server down"
CASE ELSE
        ChatLog w, "* connected"
END SELECT
END SUB

'Take the name and the room (again) after the server connection is made.
SUB ChatHello (w)
ChatSend "NAME " + BlockText$(AppGet(w, ChName))
ChatSend "JOIN " + BlockText$(AppGet(w, ChRoom))
END SUB

'One line from the relay.
SUB ChatLine (w, l$)
AppSet w, ChHb, INT(TIMER) MOD 30000
c$ = UCASE$(ChatWord$(l$, 1))
SELECT CASE c$
CASE "HB"
        'every two seconds, with the state of the relay's link to the server
        IF ChatWord$(l$, 2) = "UP" THEN
                IF AppGet(w, ChState) < 2 THEN
                        ChatState w, 2
                        ChatHello w
                END IF
        ELSE
                ChatState w, 1
        END IF
CASE "STATUS"
        IF ChatWord$(l$, 2) = "UP" THEN
                ChatState w, 2
                ChatHello w
        ELSE
                ChatState w, 1
        END IF
CASE "MSG"
        IF ChatWord$(l$, 2) = BlockText$(AppGet(w, ChRoom)) THEN
                ChatLog w, "<" + ChatWord$(l$, 3) + "> " + ChatRest$(l$, 3)
        END IF
CASE "DM"
        ChatLog w, "*" + ChatWord$(l$, 2) + "* " + ChatRest$(l$, 2)
CASE "SENT"
        ChatLog w, "-> " + ChatWord$(l$, 2) + ": " + ChatRest$(l$, 2)
CASE "JOIN"
        ChatLog w, "* " + ChatWord$(l$, 3) + " joined " + ChatWord$(l$, 2)
CASE "LEAVE"
        ChatLog w, "* " + ChatWord$(l$, 3) + " left " + ChatWord$(l$, 2)
CASE "USERS"
        ChatLog w, "users: " + ChatRest$(l$, 2)
CASE "ERR"
        ChatLog w, "! " + ChatRest$(l$, 2)
END SELECT
END SUB

'Read what came in, a line at a time, and look at the clock.
SUB ChatTimer (w, tag)
got$ = ChatRecv$(w)
IF LEN(got$) > 0 THEN
        rx$ = BlockText$(AppGet(w, ChRx)) + got$
        DO
                p = INSTR(rx$, CHR$(10))
                IF p = 0 THEN EXIT DO
                l$ = LEFT$(rx$, p - 1)
                rx$ = MID$(rx$, p + 1)
                IF RIGHT$(l$, 1) = CHR$(13) THEN l$ = LEFT$(l$, LEN(l$) - 1)
                ChatLine w, l$
        LOOP
        IF LEN(rx$) > 300 THEN rx$ = ""
        BlockSetText AppGet(w, ChRx), rx$
END IF
IF AppGet(w, ChState) > 0 THEN
        gone = (INT(TIMER) MOD 30000 - AppGet(w, ChHb) + 30000) MOD 30000
        IF gone > 6 THEN ChatState w, 0
END IF
TimerSet AppIdChat, w, 1, .1
END SUB

'The text box was accepted: a command, or a message to the room.
SUB ChatEvent (w, ctl)
IF ctl <> AppGet(w, ChInput) THEN EXIT SUB
t$ = CtlGetText$(ctl)
CtlSetText ctl, ""
ChatCommand w, t$
END SUB

SUB ChatCommand (w, t$)
IF LEN(t$) = 0 THEN EXIT SUB
IF AppGet(w, ChState) < 2 THEN
        ChatLog w, "! not connected"
        EXIT SUB
END IF
room$ = BlockText$(AppGet(w, ChRoom))
IF LEFT$(t$, 1) <> "/" THEN
        ChatSend "MSG " + room$ + " " + t$
        EXIT SUB
END IF
SELECT CASE LCASE$(ChatWord$(t$, 1))
CASE "/name"
        ChatSend "LEAVE " + room$
        ChatSend "NAME " + ChatWord$(t$, 2)
        BlockSetText AppGet(w, ChName), ChatWord$(t$, 2)
        ChatSend "JOIN " + room$
CASE "/join"
        ChatSend "LEAVE " + room$
        BlockSetText AppGet(w, ChRoom), ChatWord$(t$, 2)
        ChatSend "JOIN " + ChatWord$(t$, 2)
CASE "/dm"
        ChatSend "DM " + ChatWord$(t$, 2) + " " + ChatRest$(t$, 2)
CASE "/who"
        ChatSend "WHO " + room$
CASE ELSE
        ChatLog w, "! /name /join /dm /who"
END SELECT
END SUB

'The log is bottom aligned above the status line and the input box, which sit
'at the bottom of the client area: the window can be any size.
SUB ChatPaint (w)
IF UiLayout THEN
        CtlPlace AppGet(w, ChInput), 4, UiH - 28, UiW - 8, 24
        EXIT SUB
END IF
rows = (UiH - 56) \ 17
IF rows > ChLines THEN rows = ChLines
FOR i = 0 TO rows - 1
        UiLabel 8, UiH - 52 - (i + 1) * 17, UiW - 16, 17, BlockText$(AppGet(w, ChLine + ChLines - 1 - i))
NEXT
SELECT CASE AppGet(w, ChState)
CASE 0
        s$ = "Disconnected: no relay"
CASE 1
        s$ = "Relay up, server down"
CASE ELSE
        s$ = BlockText$(AppGet(w, ChName)) + " in " + BlockText$(AppGet(w, ChRoom))
END SELECT
UiLabel 8, UiH - 50, UiW - 16, 16, s$
END SUB
