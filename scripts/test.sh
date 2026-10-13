#!/usr/bin/env bash
# Run the Snuggle OS tests in QBasic 1.1 inside headless DOSBox.
#
#   scripts/test.sh            smoke run of SNUGGLE.BAS, then the pixel and write-count cases
#   TEST_TIMEOUT=300 ...       seconds a run may take (default 900)
#
# 1. smoke: SNUGGLE.BAS as shipped, stopped right after its first paint.
# 2. cases: tests/*.bas spliced into SNUGGLE.BAS (tests/build_test.py). The cases
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

python3 -I "$root/tests/build_test.py" > "$build/TEST.BAS"
python3 -I "$root/tests/build_test.py" --smoke > "$build/SMOKE.BAS"

# One DOSBox run: run_dosbox <BAS file> <file the program writes when it is done> <done pattern>
cat > "$build/inner.sh" <<'INNER'
#!/usr/bin/env bash
bas="$1"; marker="$2"; pattern="$3"; limit="$4"; build="$5"
cat > "$build/dosbox.conf" <<CONF
[sdl]
fullscreen=false
output=surface
[dosbox]
machine=vgaonly
[cpu]
cycles=max
[mixer]
nosound=true
[sblaster]
sbtype=none
[gus]
gus=false
[speaker]
pcspeaker=false
[midi]
mpu401=none
mididevice=none
[autoexec]
mount c $build
c:
QBASIC /RUN $bas
exit
CONF
cd "$build"
SDL_AUDIODRIVER=dummy timeout "$limit" dosbox -conf "$build/dosbox.conf" -noconsole >"$build/dosbox.log" 2>&1 &
pid=$!
for n in $(seq 1 "$limit"); do
  kill -0 $pid 2>/dev/null || break
  grep -q "$pattern" "$build/$marker" 2>/dev/null && break
  # The program creates its marker file in the first seconds. Without it after
  # 90 s QBasic stopped on a syntax error or crashed: do not wait for the limit.
  if [ "$n" -ge 90 ] && [ ! -f "$build/$marker" ]; then break; fi
  sleep 1
done
kill $pid 2>/dev/null || true
wait $pid 2>/dev/null || true
INNER
chmod +x "$build/inner.sh"

if command -v dosbox >/dev/null && command -v xvfb-run >/dev/null; then
  launch=(xvfb-run -a -s '-screen 0 800x600x24')
else
  launch=(nix shell nixpkgs#dosbox nixpkgs#xvfb-run nixpkgs#coreutils nixpkgs#gnugrep --command xvfb-run -a -s '-screen 0 800x600x24')
fi

# DOSBox 0.74 sometimes segfaults while it switches to SCREEN 12 under Xvfb. A
# crash shows as a run that ends in seconds without its marker: run it again.
run_dosbox() { # bas marker pattern
  local attempt started
  for attempt in 1 2 3 4 5; do
    rm -f "$build/$2"
    started=$SECONDS
    "${launch[@]}" "$build/inner.sh" "$1" "$2" "$3" "$limit" "$build" || true
    grep -q "$3" "$build/$2" 2>/dev/null && return 0
    [ $((SECONDS - started)) -ge 20 ] && return 1
    echo "DOSBox ended after $((SECONDS - started)) s without finishing (attempt $attempt), retrying" >&2
  done
  return 1
}

status=0

echo "== smoke: SNUGGLE.BAS starts and paints"
if run_dosbox SMOKE.BAS SMOKE.TXT '^started'; then
  echo "PASS SNUGGLE.BAS starts, opens its windows and paints"
else
  echo "FAIL SNUGGLE.BAS did not reach its main loop (syntax or runtime error?)"
  exit 2
fi

echo "== cases"
if ! run_dosbox TEST.BAS RESULT.TXT '^DONE'; then
  [ -f "$build/RESULT.TXT" ] && cat "$build/RESULT.TXT"
  echo "Test run did not finish (no DONE line)." >&2
  exit 2
fi

python3 -I "$root/tests/verify.py" "$build" || status=1
grep -v '^SNAP \|^DONE' "$build/RESULT.TXT" || true
if grep -q '^FAIL' "$build/RESULT.TXT"; then status=1; fi
[ "$status" = 0 ] && echo "All cases passed." || echo "FAILED" >&2
exit $status
