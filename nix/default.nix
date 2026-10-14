# Everything the flake offers, in one place.
#
#   qbasic    QBASIC.EXE out of the vendored archive
#   tools     the Rust workspace: snuggle (build, docs, test) and the chat programs
#   program   SNUGGLE.BAS, built by snuggle from os/
#   desktop   what `nix run` starts
#   web       the page (original and modern), its chat server, a container image
#   checks    cargo test (during the build of tools), the docs
{ pkgs, src }:
let
  inherit (pkgs) lib;

  qbasic = pkgs.callPackage ./qbasic.nix { };
  tools = pkgs.callPackage ./tools.nix { inherit src qbasic; };
  program = pkgs.callPackage ./program.nix { inherit tools; };
  desktop = pkgs.callPackage ./desktop.nix { inherit program qbasic; };
  web = pkgs.callPackage ./web.nix { inherit tools program qbasic; };

  groups = [ "window" "controls" "heap" "apps" "input" "speed" "chat" "chatloss" "chatweb" ];

  # One derivation per group: headless DOSBox in a virtual X server.
  testGroup = name: pkgs.runCommand "snuggle-test-${name}" { nativeBuildInputs = [ tools ]; } ''
    export HOME=$TMPDIR
    mkdir -p work $out
    snuggle test ${name} --work $PWD/work | tee $out/log
    grep -q '^All cases passed' $out/log
  '';
in
rec {
  packages = {
    inherit qbasic tools program desktop;
    default = desktop;
    snuggle-os = desktop;
    snuggle-tools = tools;
    web-site = web.site;
    web-image = web.image;
  }
  # The QBasic groups as derivations. DOSBox 0.74 segfaults at its first frame
  # in the Nix build sandbox (SDL_UpdateRects), so they are not in `checks`;
  # `nix run .#test` runs them outside the sandbox.
  // lib.optionalAttrs pkgs.stdenv.isLinux (lib.genAttrs (map (g: "test-${g}") (groups ++ [ "smoke" ])) (n: testGroup (lib.removePrefix "test-" n)));

  apps =
    let
      app = drv: bin: { type = "app"; program = "${drv}/bin/${bin}"; };
    in
    {
      default = app desktop "snuggle-os";
      snuggle = app tools "snuggle";
      web = { type = "app"; program = "${web.run}"; };
      chat-server = app tools "snuggle-chat-server";
      chat-relay = app tools "snuggle-chat-relay";
      test = {
        type = "app";
        program = toString (pkgs.writeShellScript "snuggle-test" ''
          exec ${tools}/bin/snuggle test "$@"
        '');
      };
      shot = {
        type = "app";
        program = toString (pkgs.writeShellScript "snuggle-shot" ''
          exec ${tools}/bin/snuggle shot -o "''${1:-snuggle.png}"
        '');
      };
      fetch-docs = {
        type = "app";
        program = "${pkgs.callPackage ./fetch-docs.nix { }}/bin/snuggle-fetch-docs";
      };
    };

  checks = lib.optionalAttrs pkgs.stdenv.isLinux (
    {
      inherit tools; # its checkPhase is `cargo test` of the whole workspace
      program = program;
      docs = pkgs.runCommand "snuggle-docs-current" { nativeBuildInputs = [ tools ]; } ''
        snuggle check
        touch $out
      '';
    }
  );

  devShell = pkgs.mkShell {
    packages = with pkgs; [
      cargo rustc clippy rustfmt rust-analyzer
      dosbox xvfb unzip
      nixpkgs-fmt
    ];
    # snuggle finds QBASIC.EXE by itself (unzip of vendor/qb11.zip) in a checkout.
    shellHook = ''
      export PATH="$PWD/target/release:$PWD/target/debug:$PATH"
    '';
  };
}
