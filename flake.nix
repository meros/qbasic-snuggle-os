{
  description = "Snuggle OS: a 1999 QBasic desktop, run in DOSBox";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

  outputs = { self, nixpkgs }:
    let
      systems = [ "x86_64-linux" "aarch64-linux" "x86_64-darwin" "aarch64-darwin" ];
      forAll = f: nixpkgs.lib.genAttrs systems (system: f nixpkgs.legacyPackages.${system});
    in
    {
      packages = forAll (pkgs: rec {
        snuggle-os = pkgs.callPackage ./nix/package.nix { };
        # the chat server and the host relay (docs/CHAT.md)
        snuggle-chat = pkgs.rustPlatform.buildRustPackage {
          pname = "snuggle-chat";
          version = "0.1.0";
          src = ./chat;
          cargoLock.lockFile = ./chat/Cargo.lock;
        };
        default = snuggle-os;
      });

      # nix run             opens the desktop in a DOSBox window
      # nix run .#test      runs the test harness (headless DOSBox in a virtual X server)
      # nix run .#chat-server, .#chat-relay   the chat parts (docs/CHAT.md)
      apps = forAll (pkgs: {
        default = {
          type = "app";
          program = "${self.packages.${pkgs.system}.snuggle-os}/bin/snuggle-os";
        };
        chat-server = {
          type = "app";
          program = "${self.packages.${pkgs.system}.snuggle-chat}/bin/snuggle-chat-server";
        };
        chat-relay = {
          type = "app";
          program = "${self.packages.${pkgs.system}.snuggle-chat}/bin/snuggle-chat-relay";
        };
        test = {
          type = "app";
          program = "${pkgs.callPackage ./nix/test.nix { src = self; }}/bin/snuggle-os-test";
        };
      });

      devShells = forAll (pkgs: {
        default = pkgs.mkShell {
          packages = [ pkgs.dosbox pkgs.xvfb-run pkgs.scrot pkgs.python3 pkgs.unzip ];
        };
      });
    };
}
