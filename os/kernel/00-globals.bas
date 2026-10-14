'SNUGGLE OS ALPHA!
'Copyright 1999 Alexander Schrab
'Thanks to:
'UPA for help and ideas
'Mark K. Kim for the Vmouse routine (Couldn't have done it without you!!)


'***************
CONST LB = &H1      'constant for left button
'***************
CONST TtlHeight = 18
'Everything a window or an app owns lives in the heap (see 'The heap' below), in
'blocks of one kind. A block is reached by its handle: that number is the id of
'a window or a control.
CONST KWin = 1, KCtl = 2, KData = 3
CONST WfX = 0, WfY = 1, WfW = 2, WfH = 3, WfState = 4, WfApp = 5, WfData = 6, WinWords = 7
CONST CfKind = 0, CfX = 1, CfY = 2, CfW = 3, CfH = 4, CfChk = 5, CfGrp = 6, CtlWords = 7
'Controls
CONST CtlLabel = 1
CONST CtlButton = 2
CONST CtlCheck = 3
CONST CtlRadio = 4
CONST CtlText = 5
DIM SHARED GlyphData(1023) AS INTEGER   'characters 128 to 255, 16 row bytes each (characters 32 to 127 are read from SprData)
DIM SHARED Mask(15) AS INTEGER          'the 16 row bytes of the glyph being drawn, bit 7 is the left pixel

CONST HeapWords = 1023                  'the heap: 2 KB, about a dozen windows with a few controls each
CONST HeapMax = 63                      'blocks at most
DIM SHARED Heap(HeapWords) AS INTEGER
DIM SHARED HBase(HeapMax) AS INTEGER    'first word of a block
DIM SHARED HSize(HeapMax) AS INTEGER    'words in a block, 0 for a free handle
DIM SHARED HOwner(HeapMax) AS INTEGER   'window the block belongs to (a window owns itself)
DIM SHARED HKind(HeapMax) AS INTEGER    'KWin, KCtl or KData
DIM SHARED HText(HeapMax) AS STRING     'title of a window, caption of a control
DIM SHARED HeapTop AS INTEGER           'first free word: the blocks fill 0 to HeapTop - 1, no gaps
CONST TimerMax = 16
'@if timers
DIM SHARED TmUsed(TimerMax) AS INTEGER         'timers: what to call and when (see TimerSet)
DIM SHARED TmApp(TimerMax) AS INTEGER
DIM SHARED TmWin(TimerMax) AS INTEGER
DIM SHARED TmTag(TimerMax) AS INTEGER
DIM SHARED TmStart(TimerMax) AS SINGLE
DIM SHARED TmDur(TimerMax) AS SINGLE
'@endif
'@if immediate
DIM SHARED UiMode AS INTEGER            'immediate mode controls: 0 draw, 1 find the one under the pointer, 2 click
DIM SHARED UiWin AS INTEGER             'the window being painted or probed, its client area, the pointer
DIM SHARED UiOx AS INTEGER
DIM SHARED UiOy AS INTEGER
DIM SHARED UiRight AS INTEGER
DIM SHARED UiBottom AS INTEGER
DIM SHARED UiMx AS INTEGER
DIM SHARED UiMy AS INTEGER
DIM SHARED UiHitId AS INTEGER           'mode 1: the button under the pointer and where it is
DIM SHARED UiHx1 AS INTEGER
DIM SHARED UiHy1 AS INTEGER
DIM SHARED UiHx2 AS INTEGER
DIM SHARED UiHy2 AS INTEGER
DIM SHARED UiDown AS INTEGER            'mode 0: the button that looks pressed, 0 for none
DIM SHARED UiClickId AS INTEGER         'mode 2: the button that was clicked
'@endif
DIM SHARED ClientOpaque AS INTEGER      'WinDrwBrd leaves the client area alone: the app paints all of it
'@if dirty
DIM SHARED DirtyN AS INTEGER            'rectangles an app marked for repaint (WinDirty), screen coordinates
DIM SHARED DirtyWin(8) AS INTEGER
DIM SHARED DirtyX1(8) AS INTEGER
DIM SHARED DirtyY1(8) AS INTEGER
DIM SHARED DirtyX2(8) AS INTEGER
DIM SHARED DirtyY2(8) AS INTEGER
'@endif
DIM SHARED QuitFlag AS INTEGER           '-1 when the user asked to leave
DIM SHARED OomFlag AS INTEGER           '-1 when a block could not be had, set by MemAlloc
DIM SHARED WNumber AS INTEGER           'windows in WOrder, front first
DIM SHARED WNew AS INTEGER              'the window NewWin made last, 0 when it could not
DIM SHARED WOrder(HeapMax) AS INTEGER
DIM SHARED RL(1, 64, 4) AS INTEGER  'Repaint work lists of rectangles (x1, y1, x2, y2): the ones still to
                                        'paint, and the ones left after the next window. They swap roles.
DIM SHARED ClipCol AS INTEGER           'a clip one pixel thick is padded; these save the pixels
DIM SHARED ClipColX AS INTEGER          'the padding covers, so ClipOff can put them back
DIM SHARED ClipColY AS INTEGER
DIM SHARED ClipRow AS INTEGER
DIM SHARED ClipRowX AS INTEGER
DIM SHARED ClipRowY AS INTEGER
DIM SHARED VisOld(HeapMax) AS INTEGER   'which controls were drawn before a resize
DIM SHARED CtlFocus AS INTEGER          'text box that receives the keys, 0 for none
DIM SHARED CtlDown AS INTEGER           'button that is held down, 0 for none
DIM SHARED CtlEvent AS INTEGER          'control that was clicked or accepted, 0 for none
DIM SHARED SprData(9800) AS INTEGER     'ready-made glyphs 32 to 127 for each text style: PUT, no LINEs
DIM SHARED SprFg(2) AS INTEGER          'text styles: colour of the glyph and of the background behind it
DIM SHARED SprBg(2) AS INTEGER
DIM SHARED CoutBg AS INTEGER            'background colour behind the text cout draws, -1 for unknown
DIM SHARED NoSync AS INTEGER           'the tests set it: no wait for the retrace
DIM SHARED ClipActive AS INTEGER        'cout skips glyphs outside the clip
DIM SHARED ClipLX1 AS INTEGER           'the clip, the whole screen when ClipActive is 0
DIM SHARED ClipLY1 AS INTEGER
DIM SHARED ClipLX2 AS INTEGER
DIM SHARED ClipLY2 AS INTEGER
ClipLX2 = 639
ClipLY2 = 479
DIM SHARED Scratch(4100) AS INTEGER     'GET and PUT buffer: BlitMove uses all of it (8000 bytes), ClipOn saves
                                        'a column in 0 to 961 and a row in 1000 to 1162
DIM SHARED MouseAsm AS STRING    'machine code for the mouse driver call
DIM SHARED MouseOK AS INTEGER
DIM SHARED MouseVis AS INTEGER
DIM SHARED IconApp(7) AS INTEGER        'desktop icons: the app they start, where they are, their name
DIM SHARED IconX(7) AS INTEGER
DIM SHARED IconY(7) AS INTEGER
DIM SHARED IconText(7) AS STRING
DIM SHARED IconCount AS INTEGER


DEFINT A-Z
'@@RUN-BEGIN
SCREEN 12
enabled% = mouse.enable
mouse.show
Init
CLS

AppStartAll
refresh

DO
MainStep
LOOP UNTIL QuitFlag
'@@RUN-END
