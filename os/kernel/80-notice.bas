'Part notice: a line of text on the top of the screen.

'@if notice
'A line of text on a bar at the top of the screen. The next repaint of that
'area removes it.
'@api Windows | Show a line of text on the bar at the bottom of the screen for 4 seconds.
SUB Notice (msg$)
mouse.hide
gFill 0, 0, 639, 15, 5
cout msg$, 8, -1, 15, 624, 0
mouse.show
TimerSet 0, 0, 1, 4
END SUB
'@else
SUB Notice (msg$)
END SUB
'@endif
