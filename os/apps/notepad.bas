'@app id=4 name=Notepad start=NotepadStart paint=NotepadPaint key=NotepadKey uses=immediate,blocks
'Notepad: ten lines of up to 40 characters, a line editor. Typing adds to the
'current line, Backspace takes the last character off, Enter and the arrow keys
'move between lines. Save writes NOTE.TXT and Load reads it. The lines are
'blocks of the window's own (BlockText$), the buttons and the text are
'immediate mode, so the window holds no controls.
'Data words: 0 the current line, 1 to 10 the line blocks, 11 the status line.
CONST NpCur = 0, NpLine = 1, NpMsg = 11, NpLines = 10, NpWidth = 40

SUB NotepadStart
w = AppWindow(AppIdNotepad, "Notepad", 150, 50, 340, 250, 12)
FOR i = 0 TO NpLines - 1
        AppSet w, NpLine + i, AppBlock(w)
NEXT
AppSet w, NpMsg, AppBlock(w)
END SUB

SUB NotepadPaint (w)
cur = AppGet(w, NpCur)
FOR i = 0 TO NpLines - 1
        t$ = BlockText$(AppGet(w, NpLine + i))
        IF i = cur THEN t$ = t$ + "_"
        UiLabel 8, 4 + i * 18, 320, 18, t$
NEXT
IF UiButton(1, 8, 192, 60, 24, "Save") THEN NotepadSave w
IF UiButton(2, 76, 192, 60, 24, "Load") THEN NotepadLoad w
UiLabel 150, 196, 180, 16, BlockText$(AppGet(w, NpMsg))
END SUB

SUB NotepadKey (w, k$)
cur = AppGet(w, NpCur)
h = AppGet(w, NpLine + cur)
t$ = BlockText$(h)
IF LEN(k$) = 2 AND LEFT$(k$, 1) = CHR$(0) THEN
        'arrow keys
        IF RIGHT$(k$, 1) = "H" AND cur > 0 THEN cur = cur - 1
        IF RIGHT$(k$, 1) = "P" AND cur < NpLines - 1 THEN cur = cur + 1
ELSEIF LEN(k$) = 1 THEN
        c = ASC(k$)
        IF c = 8 THEN
                IF LEN(t$) > 0 THEN BlockSetText h, LEFT$(t$, LEN(t$) - 1)
        ELSEIF c = 13 THEN
                IF cur < NpLines - 1 THEN cur = cur + 1
        ELSEIF c >= 32 AND LEN(t$) < NpWidth THEN
                BlockSetText h, t$ + k$
        END IF
END IF
AppSet w, NpCur, cur
BlockSetText AppGet(w, NpMsg), ""
WinInvalidate w
END SUB

SUB NotepadSave (w)
f = FREEFILE
OPEN "NOTE.TXT" FOR OUTPUT AS #f
FOR i = 0 TO NpLines - 1
        PRINT #f, BlockText$(AppGet(w, NpLine + i))
NEXT
CLOSE #f
BlockSetText AppGet(w, NpMsg), "Saved NOTE.TXT"
END SUB

SUB NotepadLoad (w)
f = FREEFILE
OPEN "NOTE.TXT" FOR BINARY AS #f
n& = LOF(f)
CLOSE #f
IF n& = 0 THEN
        KILL "NOTE.TXT"
        BlockSetText AppGet(w, NpMsg), "No NOTE.TXT"
        EXIT SUB
END IF
OPEN "NOTE.TXT" FOR INPUT AS #f
FOR i = 0 TO NpLines - 1
        l$ = ""
        IF NOT EOF(f) THEN LINE INPUT #f, l$
        BlockSetText AppGet(w, NpLine + i), LEFT$(l$, NpWidth)
NEXT
CLOSE #f
BlockSetText AppGet(w, NpMsg), "Loaded NOTE.TXT"
END SUB
