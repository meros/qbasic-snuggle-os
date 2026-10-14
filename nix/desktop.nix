# What `nix run` starts: DOSBox with the program, in a window. The chat relay
# can dial its serial port (port 7001, docs/CHAT.md).
{ lib, writeShellApplication, writeText, dosbox, coreutils, program, qbasic }:
let
  conf = writeText "snuggle-dosbox.conf" ''
    [sdl]
    fullscreen=false
    autolock=false
    windowresolution=1280x960
    output=opengl
    [render]
    aspect=true
    [cpu]
    cycles=max
    [serial]
    serial1=nullmodem port:7001 transparent:1
    [autoexec]
    mount c @WORK@
    c:
    QBASIC /RUN SNUGGLE.BAS
    exit
  '';
in
writeShellApplication {
  name = "snuggle-os";
  runtimeInputs = [ dosbox coreutils ];
  text = ''
    work="$(mktemp -d "''${TMPDIR:-/tmp}/snuggle-os.XXXXXX")"
    cp ${qbasic}/QBASIC.EXE ${program}/SNUGGLE.BAS "$work"/
    chmod u+w "$work"/*
    sed "s|@WORK@|$work|" ${conf} > "$work/dosbox.conf"
    # DOSBox runs as a child that the launcher stops: a plain exec would leave
    # the scratch directory behind, and a killed launcher would leave DOSBox at
    # full CPU (cycles=max).
    dosbox -conf "$work/dosbox.conf" -noconsole &
    pid=$!
    trap 'kill "$pid" 2>/dev/null || true; rm -rf "$work"' EXIT INT TERM HUP
    wait "$pid"
  '';
}
