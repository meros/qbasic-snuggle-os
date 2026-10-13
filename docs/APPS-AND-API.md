# Freestanding apps and an API for Snuggle OS

## In short

Snuggle OS runs inside QBasic 1.1, which has no linker, no compiler and no way
to load a second program next to the first. Real freestanding apps (separate
files that run beside each other) are therefore not possible without moving the
"OS" out of QBasic. Three cheaper designs work. The best fit is apps that are
compiled into the desktop by a build script, against a small documented API of
`Win*` and `g*` procedures plus four callbacks (paint, click, key, tick). The
clipped redraw added on this branch is what makes that API small: an app only
draws its own window and never has to think about other windows.

Nothing in this note is built yet. The experiments below ran; the designs did
not.

## What the environment allows

Results of small test programs run in QBasic 1.1 under DOSBox 0.74-3 (the same
setup as `scripts/test.sh`).

| Question | Result | Evidence |
| --- | --- | --- |
| Does `CHAIN` pass `COMMON` variables to the next program? | Yes. An integer (1234) and a string arrived intact. | `CHAIN "CB.BAS"` with `COMMON SHARED passed%, note$` |
| Does `CHAIN` keep the graphics mode and the pixels on screen? | Yes. `POINT(20, 20)` returned the colour drawn by the first program, and the mode was still graphics. | same test |
| Does `$INCLUDE` of a `.BI` file (a `CONST` and a `DECLARE`) work? | No. The program did not start (no output file, run stalled). I could not see the error text. | `'$INCLUDE: 'INCL.BI'` |
| Does the screen survive `RUN "other.bas"`? | Not shown. `POINT` after `RUN` stalled with an empty output file, which fits a reset to text mode. I did not confirm that separately. | `RN.BAS` |
| Can QBasic 1.1 build an `.EXE`? | No tool for it in `qb11.zip`: the archive holds only `QBASIC.EXE` and `QBASIC.HLP`. | `unzip -l qb11.zip` |
| Can it call a DOS interrupt? | `CALL ABSOLUTE` is built in, and `SNUGGLE.BAS` uses it for the mouse (machine code in a string). The `INTERRUPT` statement needs an external library in QBasic and QuickBASIC. | QB64 wiki pages for `CALL ABSOLUTE` and `INTERRUPT` in `docs/qbasic/` |

So inside QBasic the only multi-program tools are `CHAIN`+`COMMON` and
`RUN`. Neither runs two programs at the same time.

## Three designs

### A. Compiled-in apps (recommended first step)

An app is a `.bas` file with its own procedures. A build script (the same idea
as `tests/build_test.py`, which already splices files into `SNUGGLE.BAS`) joins
the kernel and the chosen apps into one program. The kernel calls the app
through a generated `SELECT CASE` on an app number, because QBasic has no
function pointers.

- **Concurrency:** yes, in the cooperative sense. The main loop gives each app a
  turn.
- **"Freestanding":** the source is separate; the running program is not.
- **Cost:** low. Everything needed exists in the engine now.
- **Limit (not measured here):** one QBasic module has a size limit. The file
  is now about 1,300 lines; I do not know how much room is left.

### B. Apps as separate programs with `CHAIN`

Each app is its own `.bas`. The desktop saves its window list in `COMMON`
variables, chains to the app, and the app chains back.

- **Concurrency:** none. One app at a time, and the desktop is gone while the
  app runs.
- **Evidence it can work:** the `CHAIN` result above (screen and variables
  survive).
- **Cost:** medium. The window and font arrays must travel in `COMMON` (the
  font tables alone are about 39,000 integers; I did not test arrays of that
  size in `COMMON`), or each chain must rebuild them (about 1 to 2 s for the
  font).
- **Fit:** poor for a windowed desktop.

### C. Apps as data (a small interpreter)

An app is a text file in a tiny language: `WINDOW`, `TEXT`, `BUTTON`,
`ON CLICK`. The kernel reads the file and interprets it, a few steps per loop
pass.

- **Concurrency:** yes, and apps cannot crash the desktop.
- **Freestanding:** yes. Drop a file in the folder; no rebuild.
- **Cost:** high. A parser, a command set, and a stable language to keep.
- **Fit:** best for user-made apps, worst for anything fast.

### Not available: native DOS programs

A true freestanding app would be a compiled `.EXE` calling the desktop through
an interrupt (for example `INT 60h`), with the desktop as a resident program.
That needs an assembler or C compiler for DOS and a desktop that is not written
in QBasic. It is a different project.

## A small API (design for design A)

The engine already has most of this. The new part is the app side.

```
Kernel services (exist now)
  NewWin text$, x, y, w, h        create a window, returns through WNumber
  WinMoveTo who, x, y             move; repaints only what changed
  WinSizeTo who, w, h             resize
  WinSetState who, state          0 rolled up, 1 normal, 2 maximised
  WinPutTop who                   raise
  WinRect who, x1, y1, x2, y2     window rectangle
  RepaintRect x1, y1, x2, y2      repaint a screen area from the window list
  gFill, gBox, gLine, gPset       draw, inside the current clip
  cout text$, x, y, colour, w, 0  text with the built-in font
  mouse.getpos, mouse.getbutton   pointer

Callbacks an app provides (new)
  AppPaint who, x1, y1, x2, y2    draw your client area; the clip is already set
  AppClick who, x, y, buttons     a click inside the client area
  AppKey who, k$                  a key, when this window is on top
  AppTick who                     once per main-loop pass (timers, animation)

Services an app calls (new)
  WinInvalidate who               "my content changed": repaint the client area
```

Why the callbacks stay this small: `RepaintRect` already calls the window
drawing routine once per visible piece, with a clip active (`ClipOn`). If
`WinDrwMng` calls `AppPaint` for the client area, an app is painted correctly
under overlap, partial cover and off-screen placement with no code of its own
for any of those. Before this branch each app would have had to handle
occlusion, and the 1999 redraw could not have supported it.

Rules the API needs:

1. **Unique names.** One module means one name space. Prefix every app
   procedure and variable (`Clock_Paint`, `Clock_secs`).
2. **State per window.** Index app state by window number, or keep a `TYPE`
   array.
3. **No direct `SCREEN` or `VIEW` calls.** The kernel owns the clip.
4. **Draw only in `AppPaint`.** Anything else can write outside the clip.
5. **Keep a paint short.** A paint can run once per visible piece and once per
   mouse step during a drag.

## An API for the outside (the browser host)

The container serves the game through js-dos. The README of js-dos 6.22 shows
the browser API as `Dos(canvas).ready((fs, main) => ...)`, where `fs.extract`
mounts an archive as `C:` and `main([...])` starts DOSBox with command-line
arguments. Two consequences:

- A web API for apps is a file API: serve the app files, let the page put them
  into the DOS file system before `main` runs. Design A needs a rebuild, so
  this fits design C (data apps) better.
- The package the `Dockerfile` uses, `create-dosbox`, says in its README that it
  is deprecated and based on an old js-dos. Any host API work should start with
  moving to the current js-dos, not building on it.

I did not read the `fs` API page, so I do not list its functions here.

## Recommendation and next steps

1. Build design A. Keep the API above as the contract and write one sample app
   (a clock, using `AppTick` and `WinInvalidate`) to test the callbacks.
2. Add the build script (`scripts/build.sh`) that joins kernel and apps and
   writes `SNUGGLE.BAS`. The test harness already proves that a script can
   splice files for QBasic.
3. Add API tests to `tests/`: an app that draws a full-window pattern, covered
   and uncovered in turn, compared against the reference as the other cases are.
4. Decide on design C only if you want apps without a rebuild.

## Unverified

- Module size and data-segment limits of QBasic 1.1 for a merged program.
- Whether `COMMON` can carry arrays the size of the font tables.
- Why `$INCLUDE` failed (the dialog text could not be read headless).
- The js-dos `fs` and `ci` function list.
