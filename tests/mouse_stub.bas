'The cases drive the program through its own procedures; the mouse is a script.
'MsAdd puts a state (x, y, buttons) at the end of the script. Every poll of the
'buttons moves to the next state, so any loop that waits for the button to go
'up ends when the script does (and the buttons read 0 after its last state).
FUNCTION mouse.enable%
mouse.enable = 0
END FUNCTION

FUNCTION mouse.getbutton%
IF MsI < MsN THEN
        MsI = MsI + 1
        MsCx = MsX(MsI)
        MsCy = MsY(MsI)
        MsCb = MsB(MsI)
ELSE
        MsCb = 0
END IF
mouse.getbutton = MsCb
END FUNCTION

SUB mouse.getpos (x%, y%)
x% = MsCx
y% = MsCy
END SUB

SUB mouse.hide
END SUB

SUB mouse.show
END SUB

'The queued keys of the test: one key (two for an arrow key) at a time.
FUNCTION ReadKey$
IF LEN(KeyBuf$) = 0 THEN
        ReadKey$ = ""
ELSEIF ASC(KeyBuf$) = 0 THEN
        ReadKey$ = LEFT$(KeyBuf$, 2)
        KeyBuf$ = MID$(KeyBuf$, 3)
ELSE
        ReadKey$ = LEFT$(KeyBuf$, 1)
        KeyBuf$ = MID$(KeyBuf$, 2)
END IF
END FUNCTION
