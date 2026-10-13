'The cases drive the program through its own procedures, not the mouse driver.
'These stand in for the vendored mouse library, which is about 10 KB of code and
'would push the test build over what QBasic 1.1 will start.
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

FUNCTION mouse.loadgcr$ (filename$)
mouse.loadgcr = ""
END FUNCTION

SUB mouse.setgcr (data$)
END SUB

SUB mouse.show
END SUB
