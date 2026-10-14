# The Rust workspace: `snuggle` and the chat programs, with everything the tool
# needs to find at run time (DOSBox, a virtual X server, QBASIC.EXE, the QBasic
# sources it builds from).
{ lib, rustPlatform, makeWrapper, dosbox, xvfb, unzip, src, qbasic }:
rustPlatform.buildRustPackage {
  pname = "snuggle";
  version = "0.1.0";

  src = lib.fileset.toSource {
    root = ../.;
    fileset = lib.fileset.unions [
      ../Cargo.toml
      ../Cargo.lock
      ../crates
      ../os
      ../tests/qbasic
      ../vendor
      ../docs/API.md
    ];
  };
  cargoLock.lockFile = ../Cargo.lock;

  nativeBuildInputs = [ makeWrapper ];

  # cargo test runs in checkPhase (doCheck is on)
  postInstall = ''
    mkdir -p $out/share/snuggle/tests $out/share/snuggle/docs
    cp -r os vendor $out/share/snuggle/
    cp -r tests/qbasic $out/share/snuggle/tests/
    cp docs/API.md $out/share/snuggle/docs/
    wrapProgram $out/bin/snuggle \
      --prefix PATH : ${lib.makeBinPath [ dosbox xvfb unzip ]} \
      --set SNUGGLE_ROOT $out/share/snuggle \
      --set SNUGGLE_QBASIC ${qbasic}/QBASIC.EXE
  '';

  meta = {
    description = "Builds and tests Snuggle OS; the chat server and relay";
    license = lib.licenses.bsd0;
    mainProgram = "snuggle";
  };
}
