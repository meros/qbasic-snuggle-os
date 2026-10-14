# qbasic-snuggle-os

A QBasic project I did in 1999: Snuggle OS, a desktop with draggable,
mouse-driven windows, written in QBasic. It still runs today, in DOSBox in the browser, packaged in a container and
hosted on Google Cloud Run.

Live at https://snuggleos-vtmxwzy3uq-lz.a.run.app

## When

The QBasic program (`SNUGGLE.BAS`) is from 1999. The container, Terraform and
GitHub Actions setup that deploys it were added in 2020.

## How it works

- `SNUGGLE.BAS` is the original program.
- `qb11.zip` holds QBasic 1.1. The `Dockerfile` adds `SNUGGLE.BAS` and
  `dosbox.conf` to it and builds a js-dos web app with `create-dosbox`.
- `.github/workflows/build-and-deploy.yml` builds the image on every push to
  `master` and deploys it to Cloud Run with the Terraform in `terraform/`.

## Run locally

With nix (opens a DOSBox window with the desktop):

```sh
nix run github:meros/qbasic-snuggle-os-ng     # or: nix run . in a clone
```

With Docker (serves it in the browser, as in the deployment):

```sh
docker build -t snuggle-os .
docker run --rm -p 8080:8080 snuggle-os
```

Then open http://localhost:8080.

## Redraw

Windows repaint without flicker. SCREEN 12 has one video page, so there is no
page flipping, and a full off-screen copy does not fit in QBasic's 64 KB arrays.
The program redraws instead, front to back, through a clip (`VIEW SCREEN`):
each window is drawn once on the part of the changed area it shows, and what no
window covers is filled with the background. No area is erased and then
redrawn, so each changed pixel is written about once (1.03 to 1.10 writes per
changed pixel on a drag, against 2.9 to 4.9 for the 1999 code).

- `RepaintRect` paints a screen rectangle from the window list.
- `RepaintChange` paints the old and new rectangle of a window that moved,
  resized or changed state.
- `ClipOn` and `ClipOff` set the clip. A clip one pixel thick is padded and
  restored, because `VIEW SCREEN` rejects it (error 5).

### Speed

Dragging copies the window's pixels (`GET`/`PUT` in bands) and repaints only
the strips it uncovers; a resize repaints the title bar, the frame and the
area gained or lost; text is drawn from ready-made glyph sprites. Same
operations, same machine, DOSBox without the retrace wait (`scripts/test.sh`,
speed program; seconds vary by about 30%, graphics calls are exact):

| Operation | 1999 code | now | graphics calls |
| --- | --- | --- | --- |
| drag a window, 40 steps | 7.2 s | 0.65 s | 71,400 to 320 |
| resize, 20 steps | 3.2 s | 0.45 s | 36,500 to 1,980 |
| maximise, restore, roll up, unroll (x3) | 2.5 s | 0.45 s | 17,478 to 1,530 |
| toggle a checkbox, 20 times | 0.66 s | 0.16 s | 6,800 to 340 |
| full repaint, 3 times | 0.39 s | 0.11 s | 5,454 to 414 |

A drag of the front window writes each changed pixel once (1.00 writes per
changed pixel; the 1999 code wrote 2.9 to 3.7). A window that is not in front
is repainted through the clip: 1.2 writes per pixel.

## Apps and the heap

The desktop starts one instance of the Hello app at boot and shows an icon for
it on the background. A click on the icon starts another instance
(`AppLaunch`). An app is a set of procedures with a number, in the `'@@APP`
block of `SNUGGLE.BAS`. It is added by hand for now: `IconAdd` and a start
procedure in `AppStartAll`/`AppLaunch`, and a case in `AppEvent`.

| Procedure | What |
| --- | --- |
| `AppWindow(app, title$, x, y, w, h, words)` | Window for the app plus a data block of `words` words. Returns the window number, 0 when the heap has no room (`OomFlag`). |
| `AppGet(win, i)`, `AppSet win, i, v` | Word i of the window's data block (control numbers, state). An index outside the block is refused. |
| `AppEvent win, ctl` | Called by the kernel when a control of the window was clicked or accepted. |
| `WinClose win` | Closes the window: its controls and data are freed and the heap is compacted, the area is repainted. The close button calls it. |

The heap is one 4 KB array and the only allocator. A window, a control and an
app data block are blocks of it, used through handles; the handle is the id of
the window or the control. Blocks are packed from word 0 without gaps, so a free
slides the blocks above it down at once. Every block has an owner, a window; a
window owns itself, its controls and its data, and closing the window frees them
all. `MemAlloc(owner, kind, words)` returns a handle, or 0 and `OomFlag` when
the heap or the 63 handles are full. A launch that runs out of memory closes
what it made and shows a notice on the bottom bar.

## Controls

A window can hold labels, buttons, checkboxes, radio buttons and text boxes.
They are drawn in the window's client area as part of the window, so the
clipped redraw handles overlap, moving and resizing for them. Mouse and keyboard
work: a click on a button sets `CtlEvent`, a click on a text box gives it the
keys (Backspace, Enter, Esc work; 40 characters at most).

```basic
w = WNumber                                   'the window
name = CtlAdd(w, CtlText, 70, 4, 200, 22, "snuggle")   'x, y, w, h inside the client area
ok = CtlAdd(w, CtlButton, 8, 140, 80, 26, "OK")
CtlSetText name, "world"
IF CtlEvent = ok THEN PRINT CtlGetText$(name)
```

`CtlAdd`, `CtlSetText`, `CtlGetText$`, `CtlSetChecked`, `CtlGetChecked`,
`CtlSetFocus`, `CtlSelect` (radio groups), `CtlAt` (what is under a point).
A control that does not fit inside the client area is not drawn.

## Tests

```sh
scripts/test.sh            # smoke run, then 99 pixel comparisons, glyph and behaviour checks
scripts/screenshot.sh      # PNG of the program after its first paint (build/screenshot.png)
nix run .#test             # the tests, with the tools from nixpkgs
```

QBasic 1.1 runs inside headless DOSBox 0.74 under a virtual X server. The
test program draws every case with the new code and with the 1999 drawing code
(`tests/ref.bas`), dumps the screen planes with `BSAVE`, and `tests/verify.py`
compares the dumps pixel by pixel on the host. A failing case writes
`build/diff_<n>.png` (new | reference | differences). It takes about 25 s on an
idle machine. DOSBox sometimes crashes at start under Xvfb; the script runs the
test again when that happens.

The cases run as three programs (window, controls, heap, speed), and the test build
leaves out the mouse library, the hit tests, the drag loops and the palette
setup, to keep the test build inside QBasic's memory (code and arrays share
about 160 KB). `scripts/test.sh` prints the memory left after the first paint,
about 86 KB, and fails below 25 KB. A program stops starting at about 20 KB.

## Layout

| Path | What |
| --- | --- |
| `SNUGGLE.BAS` | The program. `'@@RUN-BEGIN` and `'@@GFX-BEGIN` mark the parts the tests replace. |
| `tests/` | Test cases, reference code, counting drawing layer, builder and verifier |
| `scripts/test.sh`, `scripts/dosbox-run.sh` | Test runner and the DOSBox launcher it shares |
| `scripts/screenshot.sh` | Screenshot of the program, from a video memory dump |
| `scripts/fetch-docs.sh` | Downloads QBasic reference pages into `docs/qbasic/` (not committed) |
| `docs/APPS-AND-API.md` | How apps and an API could work |
| `flake.nix`, `nix/` | `nix run` package and test app |

## Status

Maintained as a small experiment.

## License

0BSD, see [LICENSE](LICENSE). It does not cover QBasic 1.1 in `qb11.zip`
(Microsoft), the Vmouse routine by Mark K. Kim in `SNUGGLE.BAS`, or the
Apache-2.0 deploy workflow from Google.
