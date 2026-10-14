#!/usr/bin/env bash
# Run the Snuggle OS tests in QBasic 1.1 inside headless DOSBox.
#
#   scripts/test.sh            smoke run of SNUGGLE.BAS, then the pixel and write-count cases
#   TEST_TIMEOUT=300 ...       seconds a run may take (default 900)
#
# 1. smoke: SNUGGLE.BAS as shipped, stopped right after its first paint.
# 2. cases: tests/*.bas spliced into SNUGGLE.BAS (tests/build_test.py), one program
#    per group (window, controls, heap, speed). The cases
#    dump the screen planes (BSAVE) next to a reference image drawn with the 1999
#    code; tests/verify.py compares the dumps pixel for pixel on the host.
#
# Needs dosbox, xvfb-run, python3 and unzip on PATH, or nix to fetch them.
# Output and dumps go to build/ (a failing snapshot also gets build/diff_<n>.png).
set -euo pipefail

root="$(cd "$(dirname "$0")/.." && pwd)"
build="$root/build"
limit="${TEST_TIMEOUT:-900}"

mkdir -p "$build"
rm -f "$build"/RESULT.TXT "$build"/SMOKE.TXT "$build"/S*.BIN "$build"/diff_*.png
unzip -oq "$root/qb11.zip" QBASIC.EXE -d "$build"

python3 -I "$root/tests/build_test.py" --smoke > "$build/SMOKE.BAS"

. "$root/scripts/dosbox-run.sh"

status=0

echo "== smoke: SNUGGLE.BAS starts and paints"
if run_dosbox SMOKE.BAS SMOKE.TXT '^started'; then
  echo "PASS SNUGGLE.BAS starts, opens its windows and paints"
  # QBasic gives code and arrays one pool of about 160 KB, and the program needs
  # about 18 KB of it free to run (measured, docs/APPS-AND-API.md). What is left
  # after the first paint is the room for apps.
  free="$(awk '{print $2}' "$build/SMOKE.TXT" | tr -d '\r')"
  echo "     free memory after the first paint: ${free} bytes (floor ${MEM_FLOOR:-25000})"
  if [ "${free:-0}" -lt "${MEM_FLOOR:-25000}" ]; then
    echo "FAIL less than ${MEM_FLOOR:-25000} bytes of QBasic memory left"
    exit 2
  fi
else
  echo "FAIL SNUGGLE.BAS did not reach its main loop (syntax or runtime error, or DOSBox crashed five times)"
  exit 2
fi

groups="window controls heap speed"
total_fail=0
for group in $groups; do
  echo "== cases: $group"
  rm -f "$build"/RESULT.TXT "$build"/S*.BIN "$build"/diff_*.png "$build"/look_*.png
  python3 -I "$root/tests/build_test.py" --cases "$group" > "$build/TEST.BAS"
  if ! run_dosbox TEST.BAS RESULT.TXT '^DONE'; then
    [ -f "$build/RESULT.TXT" ] && cat "$build/RESULT.TXT"
    echo "Test run '$group' did not finish (no DONE line)." >&2
    exit 2
  fi
  python3 -I "$root/tests/verify.py" "$build" || status=1
  grep -v '^SNAP \|^DONE' "$build/RESULT.TXT" || true
  if grep -q '^FAIL' "$build/RESULT.TXT"; then status=1; fi
  # keep the pictures of every group
  for f in "$build"/look_*.png; do [ -f "$f" ] && mv "$f" "$build/${group}_$(basename "$f")"; done
done

[ "$status" = 0 ] && echo "All cases passed." || echo "FAILED" >&2
exit $status
