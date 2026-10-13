{ lib, writeShellApplication, dosbox, xvfb-run, scrot, python3, unzip, coreutils, gnugrep, src }:

writeShellApplication {
  name = "snuggle-os-test";
  runtimeInputs = [ dosbox xvfb-run scrot python3 unzip coreutils gnugrep ];
  # scripts/test.sh writes build/ next to the sources: run it from a writable copy.
  text = ''
    work="$(mktemp -d)"
    trap 'rm -rf "$work"' EXIT
    cp -r ${src}/. "$work"/
    chmod -R u+w "$work"
    cd "$work"
    status=0
    scripts/test.sh "$@" || status=$?
    if [ -d build ]; then
      mkdir -p "''${SNUGGLE_TEST_OUT:-$PWD/../snuggle-test-out}"
      cp -r build/. "''${SNUGGLE_TEST_OUT:-$PWD/../snuggle-test-out}"/ 2>/dev/null || true
    fi
    exit $status
  '';
}
