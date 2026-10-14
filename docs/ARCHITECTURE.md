# Architecture

## Layers

```
apps            os/apps/*.bas           Clock, Calc, Notepad, Flappy, Chat
─────────────── the app API (docs/API.md): windows, controls, timers, dirty
kernel parts    timers  immediate  dirty  blocks  controls  widgets  icons  notice
kernel core     heap · windows · repaint · text · drawing layer · mouse
QBasic 1.1 ─ DOSBox 0.74 ─ (serial) ─ relay ─ server
```

The kernel is `os/kernel/*.bas` and is joined in file name order:

| File | Holds |
| --- | --- |
| `00-globals` | constants, the shared arrays and variables, the run section |
| `10-main` | `MainStep`: one pass of the main loop |
| `20-apps` | what an app calls to make windows and data; the generated dispatch goes here |
| `30-heap` | the allocator |
| `40-window` | windows: make, close, move, size, order, hit test, drag |
| `41-chrome` | the look of a window |
| `50-repaint` | the repaint engine, clipping, blit, retrace wait |
| `60-text` | font, glyph sprites, `cout` |
| `65-gfx` | the drawing layer |
| `66-widgets` | a push button and a caption, shared by retained and immediate controls |
| `70-mouse` | mouse driver call and the keyboard |
| `80-84` | the parts: notice, immediate, timers, icons, controls |

## The repaint algorithm

Every repaint is a rectangle (`RepaintRect`). The free list starts as that
rectangle. Windows are taken front to back: each is drawn through a clip
(`VIEW SCREEN`) on the part of the free list it covers, and that part leaves the
list. What is left is background. So every pixel is written once, in its final
colour, and nothing is erased and drawn again.

- A rectangle one pixel thick cannot be a `VIEW`: the clip is padded and the
  padding saved and put back.
- `LINE` leaves a stray pixel for a box wholly below and left of the view: the
  drawing layer drops calls that are outside the clip.
- Text is a `PUT` of a ready-made 8 x 16 sprite for the four styles in use, and
  runs of `LINE` at a clip edge.
- Moving the front window is `GET`/`PUT` in bands, then repainting the strips.
- `RepaintWin` paints one window only (windows in front take their share off
  the list unpainted): what an app changes in its own window does not disturb
  windows over it.
- Desktop icons belong to the background: `DeskFill` draws them with it.

## Memory

One array, `Heap`, 1024 words. A block is `(base, size, owner, kind, text)`
indexed by handle. Blocks are packed from word 0; a free slides the blocks above
it down and fixes their bases, so there is no fragmentation and no collection
pass. A window block owns itself; a window's controls and data block are owned
by it, so closing frees them with one `MemFreeAll`.

## Parts

A part is a region of the kernel between `'@if <name>` and `'@endif`, with the
stubs of what the core calls after `'@else`. The builder takes the parts the
apps list in `uses=`, what they require, and the defaults. The tests build
programs with the apps and parts a group needs, as the program, the test code
and the reference code together do not fit in QBasic's memory.

## Apps

A manifest line, then procedures. The builder writes the dispatch (a `SELECT
CASE` on the app number for start, event, timer, paint, key), because QBasic has
no procedure pointers. State goes in the window's data block, so an app is
re-entrant.

## Tests

`snuggle test <group>` builds a program: the real one with four regions swapped
for test versions (run section, drawing layer, mouse, palette setup), then the
reference drawing code, the helpers and the cases. DOSBox runs it headless; the
program dumps the four bit planes of the screen next to a reference image drawn
by the straightforward code (`BSAVE`), and `snuggle` compares the dumps pixel by
pixel and writes PNGs of failures. See [TESTING.md](TESTING.md).

## Chat

A QBasic app on COM1 → DOSBox nullmodem (listens on 7001) ← the relay dials it
→ the server (TCP 7000). The relay is where TLS and real services would go.
See [CHAT.md](CHAT.md).

## Nix

`nix/default.nix` builds: `qbasic` (QBASIC.EXE out of the archive), `tools` (the
Rust workspace, wrapped with DOSBox, Xvfb, QBASIC.EXE and the QBasic sources),
`program` (`snuggle build`), `desktop` (the launcher). `checks` are the
workspace's `cargo test`, the docs, the smoke run and one derivation per test
group. Web hosting is not here yet: it would be a package that serves
`program` through a DOSBox in the browser.
