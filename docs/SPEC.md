# Snuggle OS: specification

What the system must do. How it does it is in [ARCHITECTURE.md](ARCHITECTURE.md).
A requirement here has a test; the group is named in brackets.

## Platform

- **P1** The program is one QBasic 1.1 source file that runs with `QBASIC /RUN`
  in DOSBox 0.74, screen mode 12 (640 x 480, 16 colours). It uses no other file.
- **P2** Code, constants and arrays share the memory QBasic gives (about 160 KB).
  The program must have at least 25 KB free after its first paint and starts
  down to about 20 KB [smoke].
- **P3** `nix run` opens the desktop; nothing else is installed on the host.

## Windows

- **W1** A window has a title, a frame, a title bar with three buttons (roll up,
  maximise, close), a client area, and a state: rolled up, normal or maximised.
- **W2** Windows overlap and have an order. A click on a window raises it [input].
- **W3** The title bar moves a window, the right and bottom borders and the corner
  resize it, the buttons act when the pointer is released on them [input].
- **W4** A repaint writes every changed pixel at most once and never shows an
  erased background between steps. Moving the front window copies its pixels and
  repaints only the uncovered strips [window, speed].
- **W5** What is on the screen after any sequence of operations equals what a
  full repaint from the window list would draw, pixel for pixel [window, controls].
- **W6** A window may be partly or fully off the screen without error [window].
- **W7** The close button frees everything the window owns [heap, input].

## Memory

- **M1** There is one allocator, the heap (2 KB, up to 63 blocks). A window, a
  control and an app's data are blocks, reached by handle.
- **M2** Freeing a block closes the gap at once; handles stay valid [heap].
- **M3** A block has an owner window; closing the window frees all of its
  blocks, controls and timers [heap].
- **M4** Running out is a refusal, never a stop: the call returns 0 and sets
  `OomFlag`; starting an app that runs out leaves nothing behind and shows a
  notice [heap].

## Controls

- **C1** Retained controls (label, text box, and with the `widgets` part button,
  check box and radio button) are blocks of the window, drawn with it
  [controls].
- **C2** Immediate mode controls (`UiButton`, `UiLabel`, `UiFill`) are declared
  by the app each time its window is painted, take no memory, and are found
  again for a click by running the same procedure [apps, input].
- **C3** A button counts a click when the mouse button is released on it
  [input].
- **C4** The keys go to the focused text box, else to the app of the front
  window when it asks for keys, else to the desktop (`R` repaints, `Q` quits)
  [input].

## Apps and the kernel's parts

- **A1** An app is one file with a manifest line; apps are joined into the
  program at build time. A part of the kernel is in the program only when an app
  uses it (or it is a default part) [build].
- **A2** An app may run in several windows; its state is in the data block of
  the window [apps].
- **A3** `TimerSet` calls the app back once after a time from the system clock,
  from the main loop; timers of a closed window are dropped [heap, apps].
- **A4** An app may mark rectangles of its client area as changed (`WinDirty`)
  and repaint only those (`WinFlush`); a window in front of it is not repainted
  by that [apps].
- **A5** The desktop background shows an icon and a name per app; windows cover
  them; a click on an icon starts an instance [window, input].

## Chat

- **H1** The chat protocol is plain ASCII lines (docs/CHAT.md): names, rooms,
  direct messages, `PING`.
- **H2** The OS reaches it through COM1, a host relay and the server. No line
  from the relay for 6 seconds is shown as disconnected, messages are refused
  while it is, and the name and room are taken again when it is back [chat,
  chatloss].
- **H3** A relay that starts after DOSBox, or restarts, is found [chatloss].

## Tests

- **T1** All tests run headless: a virtual X server of their own, the X11
  driver, the software renderer; nothing opens on the desktop.
- **T2** Each group of cases is one program; a group passes only when every
  check passed and the program said it was done.
- **T3** A test run does not leave processes behind.
