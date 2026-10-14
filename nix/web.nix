# The web host: a DOS-style page (web/) that starts the original or the modern
# Snuggle OS in js-dos (DOSBox as WebAssembly), and snuggle-web, the server for
# the page and for its chat.
#
#   site    the static files: the page, js-dos, and one bundle per variant
#   run     snuggle-web with the site, listening on $PORT or 127.0.0.1:8080
#   image   the same as a container image (Cloud Run, terraform/)
{ lib, stdenv, fetchurl, runCommand, writeText, writeShellScript, zip, dockerTools, tools, program, qbasic }:
let
  # js-dos 6.22, the WebAssembly DOSBox. Fetched from the npm registry.
  jsdos = stdenv.mkDerivation {
    pname = "js-dos";
    version = "6.22.60";
    src = fetchurl {
      url = "https://registry.npmjs.org/js-dos/-/js-dos-6.22.60.tgz";
      hash = "sha512-1EhfMftOhBZ34Gvz/RCLsAoEcgWcZ1pmumpG28Z+9oQ9oQVP90jckQpvS9NW7vvfwYJWmCj+PX+j3UO44iO6LA==";
    };
    installPhase = ''
      mkdir -p $out
      cp dist/js-dos.js dist/wdosbox.js dist/wdosbox.wasm.js $out/
    '';
  };

  conf = extra: writeText "dosbox.conf" ''
    [sdl]
    autolock=false
    [cpu]
    cycles=auto
    [autoexec]
    mount c .
    c:
    ${extra}
    QBASIC /RUN SNUGGLE.BAS
  '';

  # A js-dos bundle is a zip: the disk, and .jsdos/dosbox.conf.
  bundle = name: bas: extra: runCommand "snuggle-${name}.jsdos" { nativeBuildInputs = [ zip ]; } ''
    mkdir -p disk/.jsdos
    cp ${qbasic}/QBASIC.EXE disk/
    cp ${bas} disk/SNUGGLE.BAS
    cp ${conf extra} disk/.jsdos/dosbox.conf
    (cd disk && zip -qr $out . .jsdos)
  '';

  modern = bundle "modern" "${program}/SNUGGLE.BAS" "set SNUGGLE=web";
  original = bundle "original" ../vendor/original/SNUGGLE.BAS "";

  site = runCommand "snuggle-site" { } ''
    mkdir -p $out
    cp ${../web}/* $out/
    cp ${jsdos}/* $out/
    cp ${modern} $out/modern.jsdos
    cp ${original} $out/original.jsdos
  '';

  run = writeShellScript "snuggle-web-run" ''
    listen="''${SNUGGLE_LISTEN:-}"
    if [ -z "$listen" ] && [ -n "''${PORT:-}" ]; then listen="0.0.0.0:$PORT"; fi
    exec ${tools}/bin/snuggle-web --root ${site} \
      --listen "''${listen:-127.0.0.1:8080}" "$@"
    # "''${SNUGGLE_LISTEN:-''${PORT:+0.0.0.0:$PORT}}" "$@"
  '';
in
{
  inherit site run jsdos;
  image = dockerTools.buildLayeredImage {
    name = "snuggleos";
    tag = "latest";
    config = {
      Entrypoint = [ "${run}" ];
      ExposedPorts."8080/tcp" = { };
      Env = [ "PORT=8080" ];
    };
  };
}
