'@app id=3 name=Calc start=CalcStart paint=CalcPaint
'Calculator: digits, a decimal point, + - * / and =. An operator key finishes
'the pending operation, so 5 + 3 + shows 8. The keys are immediate mode buttons
'(CalcPaint), so they take no heap. Data words: the accumulator (a double kept
'in four words), the pending operator (its character code), 1 when the next
'digit starts a new number, and the display label.
CONST CalcAcc = 0, CalcOp = 4, CalcFresh = 5, CalcDisp = 6

FUNCTION CalcGet# (w)
s$ = ""
FOR i = 0 TO 3
        s$ = s$ + MKI$(AppGet(w, CalcAcc + i))
NEXT
CalcGet# = CVD(s$)
END FUNCTION

SUB CalcPut (w, v#)
s$ = MKD$(v#)
FOR i = 0 TO 3
        AppSet w, CalcAcc + i, CVI(MID$(s$, i * 2 + 1, 2))
NEXT
END SUB

'A number as the display shows it; too big is Error.
FUNCTION CalcFmt$ (v#)
IF ABS(v#) >= 100000000000000# THEN
        CalcFmt$ = "Error"
ELSE
        CalcFmt$ = LEFT$(LTRIM$(STR$(v#)), 14)
END IF
END FUNCTION

SUB CalcStart
n = (WNumber MOD 6) * 24
w = AppWindow(AppIdCalc, "Calculator", 60 + n, 120 + n, 198, 230, 7)
AppSet w, CalcFresh, 1
AppSet w, CalcDisp, CtlAdd(w, CtlLabel, 8, 6, 176, 16, "0")
END SUB

'The keys. Button ids are 1 to 16 for the grid and 17 for C (0 means none).
SUB CalcPaint (w)
keys$ = "789/456*123-0.=+"
FOR i = 0 TO 15
        k$ = MID$(keys$, i + 1, 1)
        IF UiButton(i + 1, 8 + (i MOD 4) * 44, 32 + (i \ 4) * 34, 40, 28, k$) THEN CalcKey w, k$
NEXT
IF UiButton(17, 8, 168, 84, 28, "C") THEN CalcKey w, "C"
END SUB

SUB CalcKey (w, k$)
disp = AppGet(w, CalcDisp)
cur$ = CtlGetText$(disp)
fresh = AppGet(w, CalcFresh)
op = AppGet(w, CalcOp)
SELECT CASE k$
CASE "0" TO "9", "."
        IF fresh THEN cur$ = ""
        IF k$ = "." AND INSTR(cur$, ".") > 0 THEN k$ = ""
        IF k$ = "." AND cur$ = "" THEN cur$ = "0"
        IF cur$ = "0" AND k$ <> "." THEN cur$ = ""
        IF LEN(cur$) < 14 THEN cur$ = cur$ + k$
        AppSet w, CalcFresh, 0
CASE "C"
        cur$ = "0"
        CalcPut w, 0#
        AppSet w, CalcOp, 0
        AppSet w, CalcFresh, 1
CASE ELSE
        'an operator or =: finish what is pending, then remember this one
        v# = VAL(cur$)
        acc# = CalcGet#(w)
        IF op = 0 OR fresh THEN
                IF op = 0 THEN acc# = v#
        ELSE
                SELECT CASE CHR$(op)
                CASE "+": acc# = acc# + v#
                CASE "-": acc# = acc# - v#
                CASE "*": acc# = acc# * v#
                CASE "/"
                        IF v# = 0 THEN acc# = 1D+99 ELSE acc# = acc# / v#
                END SELECT
        END IF
        cur$ = CalcFmt$(acc#)
        IF cur$ = "Error" THEN
                acc# = 0
                op = 0
        ELSEIF k$ = "=" THEN
                op = 0
        ELSE
                op = ASC(k$)
        END IF
        CalcPut w, acc#
        AppSet w, CalcOp, op
        AppSet w, CalcFresh, 1
END SELECT
IF CtlGetText$(disp) <> cur$ THEN CtlSetText disp, cur$
END SUB
