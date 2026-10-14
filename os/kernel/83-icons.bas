'Part icons: the app icons on the desktop background.

'@if icons
'---------------------------------------------------------------------------
'Desktop icons: a picture and a name on the background. A click on one starts
'an instance of its app (AppLaunch). They are drawn with the background, so a
'window that moves over one never needs to know about it.
'---------------------------------------------------------------------------
SUB IconAdd (app, label$)
IF IconCount >= 7 THEN EXIT SUB
IconCount = IconCount + 1
IconApp(IconCount) = app
IconText(IconCount) = label$
IconX(IconCount) = 24
IconY(IconCount) = 16 + (IconCount - 1) * 64
END SUB

'The icon at a screen point, 0 for none. The name belongs to the icon.
FUNCTION IconAt (mx, my)
IconAt = 0
FOR i = 1 TO IconCount
        IF mx >= IconX(i) - 16 AND mx <= IconX(i) + 48 AND my >= IconY(i) AND my <= IconY(i) + 50 THEN IconAt = i
NEXT
END FUNCTION

'Draw the icons that touch the clip, or the screen when there is no clip.
SUB IconsDraw
FOR i = 1 TO IconCount
        x = IconX(i)
        y = IconY(i)
        n = LEN(IconText(i))
        IF NOT Outside(x - 16, y, x + 48, y + 50) THEN
                DrwBtn x, y, 31, 31
                gBox x + 7, y + 8, x + 24, y + 23, 1
                gFill x + 8, y + 9, x + 23, y + 11, 6
                gFill x + 8, y + 12, x + 23, y + 22, 15
                cout IconText(i), x + 16 - n * 4, y + 33, 15, n * 8, 0
        END IF
NEXT
END SUB

'Fill a free part of the background and put the icons on it.
SUB DeskFill (x1, y1, x2, y2)
IF IconCount = 0 THEN
        gFill x1, y1, x2, y2, 4
ELSE
        ClipOn x1, y1, x2, y2
        gFill x1, y1, x2, y2, 4
        IconsDraw
        ClipOff
END IF
END SUB
'@else
SUB IconAdd (app, label$)
END SUB

FUNCTION IconAt (mx, my)
IconAt = 0
END FUNCTION

SUB DeskFill (x1, y1, x2, y2)
gFill x1, y1, x2, y2, 4
END SUB
'@endif
