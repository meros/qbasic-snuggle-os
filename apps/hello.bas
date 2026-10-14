'@app id=1 name=Hello boot start=HelloStart event=HelloEvent timer=HelloTimer
'Hello: a window with a name box, a check box, three radio buttons and two
'buttons. OK greets the name, and the greeting goes back to Ready after 5 s.
'Clear empties the name. Data words: the control numbers.
CONST HelloWho = 0, HelloSnd = 1, HelloRed = 2, HelloBlue = 3, HelloOk = 4, HelloWipe = 5, HelloMsg = 6

SUB HelloStart
w = AppWindow(AppIdHello, "Hello", 170, 100, 300, 240, 7)
AppSet w, HelloWho, CtlAdd(w, CtlText, 70, 4, 200, 22, "snuggle")
dummy = CtlAdd(w, CtlLabel, 8, 6, 60, 16, "Name:")
AppSet w, HelloSnd, CtlAdd(w, CtlCheck, 8, 38, 170, 16, "Enable sound")
r = CtlAdd(w, CtlRadio, 8, 64, 100, 16, "Red")
AppSet w, HelloRed, r
CtlSetChecked r, 1
dummy = CtlAdd(w, CtlRadio, 8, 84, 100, 16, "Green")
AppSet w, HelloBlue, CtlAdd(w, CtlRadio, 8, 104, 100, 16, "Blue")
AppSet w, HelloOk, CtlAdd(w, CtlButton, 8, 140, 80, 26, "OK")
AppSet w, HelloWipe, CtlAdd(w, CtlButton, 100, 140, 80, 26, "Clear")
AppSet w, HelloMsg, CtlAdd(w, CtlLabel, 8, 178, 262, 16, "Ready")
END SUB

'Tag 1: the greeting goes back to Ready.
SUB HelloTimer (w, tag)
CtlSetText AppGet(w, HelloMsg), "Ready"
END SUB

SUB HelloEvent (w, ctl)
msg = AppGet(w, HelloMsg)
SELECT CASE ctl
CASE AppGet(w, HelloOk)
        CtlSetText msg, "Hello, " + CtlGetText$(AppGet(w, HelloWho))
        TimerSet AppIdHello, w, 1, 5
CASE AppGet(w, HelloWipe)
        CtlSetText AppGet(w, HelloWho), ""
        CtlSetText msg, "Ready"
CASE AppGet(w, HelloSnd)
        IF CtlGetChecked(ctl) THEN s$ = "Sound on" ELSE s$ = "Sound off"
        CtlSetText msg, s$
CASE AppGet(w, HelloRed) TO AppGet(w, HelloBlue)
        CtlSetText msg, "Colour: " + CtlGetText$(ctl)
END SELECT
END SUB
