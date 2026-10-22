# Testing

```
nix flake check             # unit tests and docs (DOSBox does not run in the Nix sandbox)
                            # CI runs this; the QBasic groups below are not in CI
nix run .#test              # everything, in the current directory
snuggle test window heap    # some groups (in nix develop, after cargo build)
snuggle groups              # the groups and the apps each has
```

## What a test is

A group is `tests/qbasic/cases/<group>.bas`: a `SUB RunAll` that sets up a scene
and calls `Check`, `CompareToLegacy` and `Metric`. `snuggle` splices it into the
program with `tests/qbasic/{ref,lib,gfx,mouse_stub,globals,run_body}.bas` and
runs it in DOSBox.

| Helper | Does |
| --- | --- |
| `Check label, ok, info$` | a pass or fail line |
| `CompareToLegacy label` | dumps the screen, repaints it from scratch with the reference code, dumps that, and the host compares them pixel for pixel |
| `Metric label, v` | a number in the output (writes, calls, seconds) |
| `Scene n` | a set of windows |
| `Click x, y`, `DragTo ...`, `Typ keys`, `MainStep` | drive the real main loop with a scripted mouse and key queue |

`gfx.bas` replaces the drawing layer with one that counts calls and pixels, so a
case can assert how much a change draws (`flappy tick writes under a tenth of a
full repaint`).

A label that starts with `look` also writes `look_<n>.png`, a picture of what
the incremental code drew; a failure writes `diff_<n>.png` (A, B, differences in
red).

## Groups

| Group | Covers |
| --- | --- |
| `window` | primitives, text, repaint of windows, incremental moves/resizes/states, desktop icons |
| `controls` | retained controls: hit tests, state, repaint |
| `heap` | the allocator, closing windows, running out, timers |
| `apps` | Clock, Calc, Flappy |
| `input` | the real main loop with a scripted mouse and keys |
| `speed` | pixels written and calls for drags, resizes, repaints |
| `chat` | Chat against the real server and relay (serial port) |
| `chatloss` | no relay, a late relay, a relay lost and back |
| `chatweb` | Chat with its lines in files, as the browser page carries them |

## Headless, and flaky

Each run starts its own Xvfb, sets `SDL_VIDEODRIVER=x11` and
`SDL_RENDER_DRIVER=software`, and removes `WAYLAND_DISPLAY`: DOSBox here is SDL
2 under a compatibility layer and would otherwise open a window on the desktop
(Wayland first), and its OpenGL renderer crashes on Xvfb. DOSBox 0.74 also
crashes at start now and then; a crash or a program that stops writing its
marker for two minutes is run again, up to five times. Core dumps are disabled
for it.

## Adding a case

1. Add checks to a group's `RunAll` (or a new `cases/<group>.bas` and an entry
   in `crates/snuggle-tools/src/testprog.rs`, and in `nix/default.nix`).
2. If a check needs an app or part that the group lacks, add it to the group's
   apps (`testprog.rs`). A group that does not start is out of memory: split it.
3. A QBasic error stops the program on a dialog and nothing is written: look at
   what changed last, and see docs/QBASIC.md for reserved words and the other
   traps.
