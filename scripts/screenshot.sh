#!/usr/bin/env bash
# Screenshot of the program as shipped, after its first paint.
#   scripts/screenshot.sh [out.png]      default: build/screenshot.png
# The video memory is dumped from inside QBasic (BSAVE of the four bit planes)
# and decoded on the host, because the DOSBox window cannot be captured headless.
set -euo pipefail

root="$(cd "$(dirname "$0")/.." && pwd)"
build="$root/build"
limit="${TEST_TIMEOUT:-300}"
out="${1:-$build/screenshot.png}"

mkdir -p "$build"
rm -f "$build"/SHOT*.BIN "$build"/SHOT.TXT
unzip -oq "$root/qb11.zip" QBASIC.EXE -d "$build"
python3 -I "$root/tests/build_test.py" --shot > "$build/SHOT.BAS"

. "$root/scripts/dosbox-run.sh"

run_dosbox SHOT.BAS SHOT.TXT '^done'
python3 -I "$root/tests/verify.py" --render "$build" SHOT "$out"
echo "$out"
