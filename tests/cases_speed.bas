'Cases: pixel writes and the cost of drags, redraws, resizes and state changes.
SUB RunAll
'4. One drag step writes each changed pixel about once. The old way did not.
Scene 1
RepaintRect 0, 0, 639, 479
MeasureDrag "drag top window by 3,2", 3, 3, 2
MeasureDrag "drag top window by 40,25", 3, 40, 25
MeasureDrag "drag back window by 8,0", 1, 8, 0

'7. Speed. Seconds depend on the machine; calls and writes do not.
Scene 4
WinPutTop 1
RepaintRect 0, 0, 639, 479
PerfStart
FOR i = 1 TO 40
        WinMoveTo 1, HGet(1, WfX) + 3, HGet(1, WfY) + 2
NEXT
PerfStop "drag the controls window, 40 steps"
CompareToLegacy "speed: after the drag"

PerfStart
FOR i = 1 TO 20
        CtlSetChecked Kc(3), i AND 1
NEXT
PerfStop "toggle a checkbox, 20 times"

PerfStart
FOR i = 1 TO 10
        CtlSetText Kc(9), "Count" + STR$(i)
NEXT
PerfStop "change a label, 10 times"

PerfStart
FOR i = 1 TO 20
        WinSizeTo 1, 340 + i * 4, 230 + i * 2
NEXT
PerfStop "resize the controls window, 20 steps"
CompareToLegacy "speed: after the resize"

PerfStart
FOR i = 1 TO 3
        WinSetState 1, 2
        WinSetState 1, 1
        WinSetState 1, 0
        WinSetState 1, 1
NEXT
PerfStop "maximise, restore, roll up, unroll, 3 times"
CompareToLegacy "speed: after the state changes"

PerfStart
FOR i = 1 TO 4
        WinPutTop Wcover
        WinPutTop 1
NEXT
PerfStop "raise two windows alternately, 8 raises"

PerfStart
FOR i = 1 TO 3
        RepaintRect 0, 0, 639, 479
NEXT
PerfStop "full repaint, 3 times"

END SUB
