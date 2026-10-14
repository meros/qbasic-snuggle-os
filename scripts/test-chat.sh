#!/usr/bin/env bash
# Chat tests: the real server and relay (Rust), DOSBox with its serial port on the
# relay, and Chat running in QBasic. Headless, like scripts/test.sh.
#
#   scripts/test-chat.sh          the Rust unit tests, then groups chat and chatloss
#
# Needs cargo, rustc and a C linker (nix shell nixpkgs#cargo nixpkgs#rustc
# nixpkgs#gcc), and what scripts/test.sh needs.
set -euo pipefail

root="$(cd "$(dirname "$0")/.." && pwd)"
build="$root/build"
limit="${TEST_TIMEOUT:-300}"
sport=17000
rport=17001
mkdir -p "$build"
unzip -oq "$root/qb11.zip" QBASIC.EXE -d "$build"

if ! command -v cargo >/dev/null; then
  exec nix shell nixpkgs#cargo nixpkgs#rustc nixpkgs#gcc nixpkgs#dosbox nixpkgs#xvfb-run \
    nixpkgs#python3 nixpkgs#unzip --command "$0" "$@"
fi

echo "== rust: unit tests and build"
(cd "$root/chat" && cargo test --quiet && cargo build --release --quiet)
srv="$root/chat/target/release/snuggle-chat-server"
rel="$root/chat/target/release/snuggle-chat-relay"

pids=()
cleanup() { for p in "${pids[@]:-}"; do kill "$p" 2>/dev/null || true; done; }
trap cleanup EXIT

. "$root/scripts/dosbox-run.sh"
# DOSBox listens, the relay dials it (a DOSBox client does not reconnect);
# transparent: plain TCP lines, no modem control framing
export DOSBOX_SERIAL1="nullmodem port:$rport transparent:1"
status=0

run_group() { # group
  rm -f "$build"/RESULT.TXT
  python3 -I "$root/tests/build_test.py" --cases "$1" > "$build/TEST.BAS"
  run_dosbox TEST.BAS RESULT.TXT '^DONE' || { cat "$build/RESULT.TXT" 2>/dev/null; echo "FAIL group $1 did not finish" >&2; return 1; }
  grep -v '^DONE' "$build/RESULT.TXT" || true
  ! grep -q '^FAIL' "$build/RESULT.TXT"
}

echo "== chat: server, relay, peer"
"$srv" --listen 127.0.0.1:$sport 2>/dev/null & pids+=($!)
sleep 0.5
"$rel" --serial 127.0.0.1:$rport --server 127.0.0.1:$sport 2>/dev/null & relay=$!; pids+=($relay)
sleep 0.5
python3 "$root/scripts/chat_peer.py" $sport &
peer=$!; pids+=($peer)
run_group chat || status=1
kill "$relay" 2>/dev/null || true
wait "$peer" 2>/dev/null || true

echo "== chatloss: no relay, a relay that comes, goes and comes back"
rm -f "$build"/START.TXT "$build"/STOP.TXT "$build"/START2.TXT
(
  while [ ! -f "$build/START.TXT" ]; do sleep 0.5; done
  "$rel" --serial 127.0.0.1:$rport --server 127.0.0.1:$sport 2>/dev/null & r=$!
  while [ ! -f "$build/STOP.TXT" ]; do sleep 0.5; done
  kill $r 2>/dev/null || true
  while [ ! -f "$build/START2.TXT" ]; do sleep 0.5; done
  "$rel" --serial 127.0.0.1:$rport --server 127.0.0.1:$sport 2>/dev/null & r=$!
  sleep 120
  kill $r 2>/dev/null || true
) &
ctl=$!; pids+=($ctl)
run_group chatloss || status=1
pkill -P "$ctl" 2>/dev/null || true
kill "$ctl" 2>/dev/null || true

[ "$status" = 0 ] && echo "Chat tests passed." || echo "FAILED" >&2
exit $status
