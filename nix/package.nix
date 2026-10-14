{ lib, stdenvNoCC, makeWrapper, dosbox, unzip, coreutils }:

stdenvNoCC.mkDerivation {
  pname = "snuggle-os";
  version = "1999-ng";

  src = lib.fileset.toSource {
    root = ../.;
    fileset = lib.fileset.unions [ ../SNUGGLE.BAS ../qb11.zip ];
  };

  nativeBuildInputs = [ makeWrapper unzip ];

  dontBuild = true;

  installPhase = ''
    runHook preInstall

    mkdir -p $out/share/snuggle-os $out/bin
    unzip -o qb11.zip QBASIC.EXE -d $out/share/snuggle-os
    cp SNUGGLE.BAS $out/share/snuggle-os/

    # SNUGGLE.BAS opens (and so creates) its cursor files in the current
    # directory, and DOSBox needs a writable C: drive: run from a scratch copy.
    cat > $out/bin/snuggle-os <<'SCRIPT'
    #!/usr/bin/env bash
    set -eu
    share="@share@"
    work="$(mktemp -d "''${TMPDIR:-/tmp}/snuggle-os.XXXXXX")"
    cp "$share"/QBASIC.EXE "$share"/SNUGGLE.BAS "$work"/
    chmod u+w "$work"/*
    cat > "$work/dosbox.conf" <<CONF
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
    mount c $work
    c:
    QBASIC /RUN SNUGGLE.BAS
    exit
    CONF
    # Run DOSBox as a child and stop it with the launcher: a plain exec would
    # leave the scratch directory behind, and a killed launcher would leave
    # DOSBox running at full CPU (cycles=max).
    dosbox -conf "$work/dosbox.conf" -noconsole &
    pid=$!
    trap 'kill "$pid" 2>/dev/null || true; rm -rf "$work"' EXIT INT TERM HUP
    wait "$pid"
    SCRIPT
    substituteInPlace $out/bin/snuggle-os --replace-fail "@share@" "$out/share/snuggle-os"
    chmod +x $out/bin/snuggle-os
    wrapProgram $out/bin/snuggle-os --prefix PATH : ${lib.makeBinPath [ dosbox coreutils ]}

    runHook postInstall
  '';

  meta = {
    description = "Snuggle OS, a mouse-driven window desktop written in QBasic in 1999";
    homepage = "https://github.com/meros/qbasic-snuggle-os";
    license = lib.licenses.bsd0;
    mainProgram = "snuggle-os";
    platforms = lib.platforms.unix;
  };
}
