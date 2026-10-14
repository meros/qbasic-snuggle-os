# QBasic 1.1 and DOSBox: what was measured

## Memory

- Code, constants and static arrays share **one pool of about 160 KB**
  (`FRE(-1)` is 159,824 in an empty program). Source costs about 1 byte of pool
  per byte (comments cost nothing), an `INTEGER` array 2 bytes per element, a
  string constant its length.
- A program starts while about **20 KB** of the pool is free at its first line
  (20.6 KB starts, about 18 KB does not). It may need that for stack and string
  work.
- A program of 125 KB source in 90 procedures starts when it has no arrays. A
  QBasic source file is not limited to 64 KB.
- An array is at most 64 KB; static arrays are in the pool, not in DGROUP.

## Language traps

- **Reserved words** (a variable or SUB with one of these name stops the load on
  "Expected: identifier" or a syntax error): `LOG`, `NAME`, `OFF`, `STEP`,
  `DRAW`, `BASE`, `SIGNAL`, `CLEAR`, `KEY` (as a name). `Hello.name` as a
  dotted name is not safe either.
- Arguments are **by reference**, also an array element: `WinClose WOrder(1)`
  changes while the procedure shifts the array. Copy first.
- A variable referenced in a SUB before its `DIM SHARED` is local: put shared
  declarations first.
- `DEFINT A-Z` is module wide. A numeric constant passed to a `SINGLE` parameter
  is converted.
- `GET`/`PUT` of an image partly outside the screen is error 5; `PUT` is not
  clipped by `VIEW`.
- `VIEW SCREEN` with a rectangle one pixel thick is error 5; one outside the
  screen too.
- `LINE` leaves a stray pixel in the corner of the view for a box wholly below
  and left of it.
- `PRINT # COM` opened `FOR RANDOM` sends no line end: add `CHR$(10)`.
- `TIMER` ticks at 18.2 Hz (about 55 ms) and wraps at midnight.
- `INKEY$` returns `CHR$(0)` plus a letter for an arrow key.
- `COLOR fg, bg` with a background is an error in SCREEN 12.
- `$INCLUDE` did not load in these tests; the program is joined before QBasic.
- A runtime error stops on a dialog: a headless run then writes nothing and
  looks like a stall.

## Graphics

- SCREEN 12 is planar and has one page: no page flipping, no full-screen back
  buffer (the 64 KB array limit).
- Attribute `n` shows DAC register `n`. QBasic's defaults for 8 to 15; the
  program sets 0 to 7 in `Init`.
- `BSAVE` of segment `&HA000` after `OUT &H3CE,4 / &H3CF,plane` dumps one bit
  plane: 38400 bytes and a 7 byte header.

## DOSBox 0.74-3 (nixpkgs: SDL 1.2 through sdl12-compat)

- It opens a **Wayland** window when `WAYLAND_DISPLAY` is set, whatever
  `DISPLAY` says. Headless needs `SDL_VIDEODRIVER=x11` and no
  `WAYLAND_DISPLAY`.
- Its OpenGL renderer crashes on Xvfb: `SDL_RENDER_DRIVER=software`.
- It segfaults at start now and then: run again. Disable core dumps.
- Serial: `serial1=nullmodem port:N transparent:1` listens; as a client
  (`server:` set) it does not reconnect. `transparent:1` passes plain TCP data
  (without it, QBasic's output does not reach a plain socket).
- `cycles=max` uses one core fully.
- The built-in mouse driver answers `int 33h`; the program calls it through a
  machine code string and `CALL ABSOLUTE`.
