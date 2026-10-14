# Snuggle OS

A small windowed desktop for **QBasic 1.1**, run in **DOSBox**. It began as a
1999 hobby program; this tree is a rebuild of it as a system with a kernel, apps,
an API, a test suite and a chat service, all built with **Nix**.

Live at https://snuggleos-vtmxwzy3uq-lz.a.run.app (type `SNUGGLE` for this
version, `ORIGINAL` for the 1999 code base).

```
nix run                      # the desktop, in a DOSBox window
nix run .#snuggle -- --help  # the tool: build, docs, test, shot
nix run .#test               # every QBasic test group, headless
nix run .#web                # the page in a browser: type SNUGGLE or ORIGINAL
nix flake check              # unit tests and docs
```

The desktop has overlapping windows that repaint without flicker, app icons
on the background, and apps: **Clock**, **Calc**, **Notepad**,
**Flappy** (a game) and **Chat** (names, rooms and direct messages through a
Rust server over the serial port).

## What is where

| Path | What | Language |
| --- | --- | --- |
| `os/kernel/` | The kernel: heap, windows, repainting, text, mouse, controls, timers, icons | QBasic |
| `os/apps/` | One file per app, with a manifest line | QBasic |
| `crates/snuggle-tools/` | `snuggle`: builds the program from `os/`, writes the API reference, runs the tests in headless DOSBox, compares screens | Rust |
| `crates/snuggle-web/` | The web host: static files, the chat hub, the chat calls of the page | Rust |
| `web/` | The DOS-style page that starts the original or the modern version in js-dos | JS |
| `vendor/original/` | The code base before the rewrite, for the page's `ORIGINAL` | QBasic |
| `terraform/` | Cloud Run for the container image of the page | HCL |
| `crates/snuggle-chat/` | The chat protocol, server, host relay and a test peer | Rust |
| `tests/qbasic/` | The QBasic side of the tests: cases, the reference drawing code, the counting drawing layer, a scripted mouse | QBasic |
| `nix/`, `flake.nix` | Packages, apps, checks, dev shell | Nix |
| `vendor/` | `qb11.zip`: Microsoft's QBASIC.EXE (see Licence) | |
| `docs/` | The documents below | |

There is no committed build output: `SNUGGLE.BAS` is made by `snuggle build`
(Nix does it) from `os/`.

## Documents

| | |
| --- | --- |
| [docs/SPEC.md](docs/SPEC.md) | What the system must do |
| [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md) | How it is built: layers, the repaint algorithm, parts, tests, Nix |
| [docs/API.md](docs/API.md) | The app API (generated from the kernel) |
| [docs/CHAT.md](docs/CHAT.md) | The chat protocol, the relay, losing the connection |
| [docs/TESTING.md](docs/TESTING.md) | How the tests work and how to add one |
| [docs/WEB.md](docs/WEB.md) | The web host, and the chat relay inside the page |
| [docs/QBASIC.md](docs/QBASIC.md) | What was measured about QBasic 1.1 and DOSBox, and the traps |

## Develop

```
nix develop                   # cargo, rustc, dosbox, a virtual X server
cargo build --release         # snuggle and the chat programs into target/release
snuggle test window           # one group (all of them with no argument)
snuggle docs -o docs/API.md   # after changing an '@api line of the kernel
```

## Licence

The code in this repository is 0BSD (LICENSE). `vendor/qb11.zip` holds Microsoft's
QBASIC.EXE, which the licence does not cover: the repository only unpacks it, and
you should check that you may keep it before you share the repository further.
The Vmouse machine code in `os/kernel/70-mouse.bas` is by Mark K. Kim.
