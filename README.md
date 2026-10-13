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

## Tests

```sh
scripts/test.sh            # smoke run, then 45 pixel comparisons and 6 write-count checks
nix run .#test             # the same, with the tools from nixpkgs
```

QBasic 1.1 runs inside headless DOSBox 0.74 under a virtual X server. The
test program draws every case with the new code and with the 1999 drawing code
(`tests/ref.bas`), dumps the screen planes with `BSAVE`, and `tests/verify.py`
compares the dumps pixel by pixel on the host. A failing case writes
`build/diff_<n>.png` (new | reference | differences). It takes about 25 s on an
idle machine. DOSBox sometimes crashes at start under Xvfb; the script runs the
test again when that happens.

## Layout

| Path | What |
| --- | --- |
| `SNUGGLE.BAS` | The program. `'@@RUN-BEGIN` and `'@@GFX-BEGIN` mark the parts the tests replace. |
| `tests/` | Test cases, reference code, counting drawing layer, builder and verifier |
| `scripts/test.sh` | Test runner |
| `scripts/fetch-docs.sh` | Downloads QBasic reference pages into `docs/qbasic/` (not committed) |
| `docs/APPS-AND-API.md` | How apps and an API could work |
| `flake.nix`, `nix/` | `nix run` package and test app |

## Status

Maintained as a small experiment.

## License

0BSD, see [LICENSE](LICENSE). It does not cover QBasic 1.1 in `qb11.zip`
(Microsoft), the Vmouse routine by Mark K. Kim in `SNUGGLE.BAS`, or the
Apache-2.0 deploy workflow from Google.
