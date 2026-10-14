'The cases drive the program through its own procedures, not the mouse driver.
'These stand in for the mouse library, so the test build keeps its memory.
FUNCTION mouse.enable%
mouse.enable = 0
END FUNCTION

FUNCTION mouse.getbutton%
mouse.getbutton = 0
END FUNCTION

SUB mouse.getpos (x%, y%)
x% = 0
y% = 0
END SUB

SUB mouse.hide
END SUB

SUB mouse.show
END SUB
