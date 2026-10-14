'The mouse and the keyboard (the tests swap it for a script).

'@@MOUSE-BEGIN
'Mouse driver (int 33h) through a machine-code string and CALL ABSOLUTE. The
'machine code is from Mark K. Kim's Vmouse routine; the five procedures that
'Snuggle OS uses share one call, MouseCall. ax, bx, cx and dx go in and come
'back as the registers after the call.
SUB MouseCall (ax, bx, cx, dx)
ofs = SADD(MouseAsm)
DEF SEG = VARSEG(MouseAsm)
CALL ABSOLUTE(d, d, d, d, ax, bx, cx, dx, 0, ofs)
DEF SEG
END SUB

'-1 when a mouse driver is installed, else 0. Run it before any other mouse call.
FUNCTION mouse.enable%
h$ = "5589E58B5E0E8B07508B5E0C8B07508B5E0A8B0F8B5E088B178B5E068E075B58CD33538B5E0E8907588B5E0C89078B5E0A890F8B5E0889175DCA1200"
MouseAsm = ""
FOR i = 1 TO LEN(h$) STEP 2
        MouseAsm = MouseAsm + CHR$(VAL("&H" + MID$(h$, i, 2)))
NEXT
MouseOK = 0
MouseCall MouseOK, b, c, d
mouse.enable = MouseOK
END FUNCTION

'Buttons that are down: LB for the left button.
FUNCTION mouse.getbutton%
bx = 0
IF MouseOK THEN MouseCall 3, bx, c, d
mouse.getbutton = bx AND 7
END FUNCTION

'The next key, "" when there is none.
FUNCTION ReadKey$
ReadKey$ = INKEY$
END FUNCTION

'Pointer position in pixels.
SUB mouse.getpos (x, y)
IF MouseOK THEN MouseCall 3, b, x, y
END SUB

SUB mouse.hide
IF MouseOK AND MouseVis THEN
        MouseCall 2, b, c, d
        MouseVis = 0
END IF
END SUB

SUB mouse.show
IF MouseOK AND NOT MouseVis THEN
        MouseCall 1, b, c, d
        MouseVis = 1
END IF
END SUB
'@@MOUSE-END
