#!/usr/bin/env bash
# Sourced by test.sh and screenshot.sh. Expects $build and $limit to be set.
# Provides run_dosbox <BAS file> <marker file the program writes> <pattern in it>.
# Runs QBasic /RUN in headless DOSBox under a virtual X server, stops when the
# marker matches, and runs again when DOSBox crashes at start.

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
# Headless means the virtual X server and nothing else. DOSBox 0.74 in nixpkgs
# runs on SDL 1.2 through sdl12-compat (SDL2), and SDL2 picks Wayland first when
# WAYLAND_DISPLAY is set, whatever DISPLAY says: the test windows then opened on
# the desktop. Take Wayland away from it and ask for X11. Its default (OpenGL)
# renderer crashes on Xvfb, which has no GLX: ask for the software one.
unset WAYLAND_DISPLAY
export SDL_VIDEODRIVER=x11
export SDL_RENDER_DRIVER=software
# DOSBox 0.74 segfaults at start now and then under Xvfb, and the runner starts
# it again. Do not let each crash become a core dump: systemd-coredump reads,
# compresses and writes every one of them, which is what bogs the machine down.
ulimit -c 0
SDL_AUDIODRIVER=dummy timeout "$limit" dosbox -conf "$build/dosbox.conf" -noconsole >"$build/dosbox.log" 2>&1 &
pid=$!
last=-1
since=$SECONDS
stalled=0
for n in $(seq 1 "$limit"); do
  kill -0 $pid 2>/dev/null || break
  grep -q "$pattern" "$build/$marker" 2>/dev/null && break
  # The program writes its marker file in the first seconds and adds to it as it
  # goes. No growth for 120 s means DOSBox stalled, or QBasic stopped on an error:
  # do not wait for the limit.
  size=$(stat -c %s "$build/$marker" 2>/dev/null || echo 0)
  if [ "$size" != "$last" ]; then last=$size; since=$SECONDS; fi
  if [ $((SECONDS - since)) -ge 120 ]; then stalled=1; break; fi
  sleep 1
done
kill $pid 2>/dev/null || true
wait $pid 2>/dev/null
code=$?
[ "$stalled" = 1 ] && code=999
echo $code > "$build/dosbox.exit"
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
  local attempt started code
  for attempt in 1 2 3 4 5; do
    rm -f "$build/$2" "$build/dosbox.exit"
    started=$SECONDS
    "${launch[@]}" "$build/inner.sh" "$1" "$2" "$3" "$limit" "$build" || true
    grep -q "$3" "$build/$2" 2>/dev/null && return 0
    code="$(cat "$build/dosbox.exit" 2>/dev/null || echo 0)"
    case "$code" in
      132|134|138|139|999) ;;                               # DOSBox crashed or stalled: run again
      *) [ $((SECONDS - started)) -ge 20 ] && return 1 ;;   # hung or stopped: give up
    esac
    echo "DOSBox ended after $((SECONDS - started)) s without finishing (exit $code, attempt $attempt), retrying" >&2
  done
  return 1
}
