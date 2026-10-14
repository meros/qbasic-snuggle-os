'Text: the screen font, glyph sprites and runs, cout.

SUB cout (text$, sx, sy, colo, Lengh, break)
'A known background and colour pair has ready-made glyphs.
st = -1
IF CoutBg >= 0 THEN
        FOR i = 0 TO 2
                IF SprFg(i) = colo AND SprBg(i) = CoutBg THEN st = i
        NEXT
END IF

charlengh = Lengh \ 8
RowChar = 0
FOR Char = 1 TO LEN(text$)
        RowChar = RowChar + 1
        IF RowChar > charlengh THEN
                IF break = 1 THEN sy = sy + 16: RowChar = 1 ELSE EXIT FOR
        END IF
        Glyph sx + (RowChar - 1) * 8, sy + 1, ASC(MID$(text$, Char, 1)), colo, st
NEXT
END SUB

'The 8 x 16 glyph of every character comes from QBasic's own screen font: the
'character is printed in colour 1 (one bit plane) and read back with GET.
'Characters 128 to 255 are kept as row bytes. Characters 32 to 127 become ready-
'made glyphs for each text style, and style 1 (black on white) doubles as their
'row bytes. Characters below 32 have no glyph.
SUB CoutSetup
COLOR 1
Pal 1, 0, 0, 0

FOR a = 128 TO 255
        LOCATE 1, 1
        PRINT CHR$(a);
        GET (0, 0)-(7, 15), Scratch
        FOR r = 0 TO 14 STEP 2
                b0 = Scratch(2 + r * 2) AND &HFF
                b1 = Scratch(4 + r * 2) AND &HFF
                IF b1 > 127 THEN GlyphData((a - 128) * 8 + r \ 2) = b0 + (b1 - 256) * 256 ELSE GlyphData((a - 128) * 8 + r \ 2) = b0 + b1 * 256
        NEXT
NEXT

'Ready-made glyphs: title text, text on the client area, text on a button.
SprFg(0) = 2: SprBg(0) = 6
SprFg(1) = 0: SprBg(1) = 15
SprFg(2) = 0: SprBg(2) = 3
CoutBg = -1
FOR c = 32 TO 127
        LOCATE 1, 1
        PRINT CHR$(c);
        GET (0, 0)-(7, 15), Scratch
        FOR r = 0 TO 15
                Mask(r) = Scratch(2 + r * 2) AND &HFF
        NEXT
        FOR st = 0 TO 2
                gFill 0, 0, 7, 15, SprBg(st)
                GlyphRows 0, 0, SprFg(st)
                spr = (st * 96 + c - 32) * 34
                gGetSprite spr
        NEXT
NEXT

END SUB

SUB Pal (i, r, g, b)
OUT &H3C8, i
OUT &H3C9, r
OUT &H3C9, g
OUT &H3C9, b
END SUB

'@@INIT-BEGIN
SUB Init
CoutSetup
Pal 0, 0, 0, 0
Pal 1, 22, 22, 22
Pal 2, 32, 32, 32
Pal 3, 42, 42, 42
Pal 4, 0, 40, 40
Pal 5, 0, 0, 22
Pal 6, 0, 0, 32
Pal 7, 0, 0, 42
END SUB
'@@INIT-END

'Draw the glyph in Mask as runs of set pixels, from the top left corner gx, gy.
SUB GlyphRows (gx, gy, colo)
FOR r = 0 TO 15
        m = Mask(r)
        bit = 128
        x0 = -1
        FOR x = 0 TO 8
                IF (m AND bit) <> 0 THEN
                        IF x0 < 0 THEN x0 = x
                ELSEIF x0 >= 0 THEN
                        gLine gx + x0, gy + r, gx + x - 1, gy + r, colo
                        x0 = -1
                END IF
                bit = bit \ 2
        NEXT
NEXT
END SUB

'One character at gx, gy. A glyph that is inside the clip and has a ready-made
'sprite for the style st is one PUT. At the edge of the clip, or without a style,
'it goes out as runs, which LINE clips.
SUB Glyph (gx, gy, num, colo, st)
IF gx + 7 < ClipLX1 OR gx > ClipLX2 OR gy + 15 < ClipLY1 OR gy > ClipLY2 THEN EXIT SUB
whole = gx >= ClipLX1 AND gx + 7 <= ClipLX2 AND gy >= ClipLY1 AND gy + 15 <= ClipLY2
IF num < 32 THEN EXIT SUB
IF st >= 0 AND whole AND num < 128 THEN
        spr = (st * 96 + num - 32) * 34
        gPutSpr gx, gy, spr
        EXIT SUB
END IF
IF num < 128 THEN
        gb = (96 + num - 32) * 34 + 2
        FOR r = 0 TO 15
                Mask(r) = (NOT SprData(gb + r * 2)) AND &HFF
        NEXT
ELSE
        FOR r = 0 TO 15
                v = GlyphData((num - 128) * 8 + r \ 2)
                IF r AND 1 THEN Mask(r) = ((v AND &HFF00) \ 256) AND &HFF ELSE Mask(r) = v AND &HFF
        NEXT
END IF
GlyphRows gx, gy, colo
END SUB
