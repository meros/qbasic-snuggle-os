SCREEN 12
Init
CLS
gVX1 = 0: gVY1 = 0: gVX2 = 639: gVY2 = 479
OPEN "RESULT.TXT" FOR OUTPUT AS #1
CLOSE #1
RunAll
Emit "DONE tests=" + STR$(TestCount) + " fails=" + STR$(TestFails)
SYSTEM
