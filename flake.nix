{
  description = "Snuggle OS: a 1999 QBasic desktop in DOSBox, built and tested with Nix and Rust";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

  outputs = { self, nixpkgs }:
    let
      # the desktop runs on these; the tests (a virtual X server) on Linux
      systems = [ "x86_64-linux" "aarch64-linux" "x86_64-darwin" "aarch64-darwin" ];
      forAll = f: nixpkgs.lib.genAttrs systems (system: f nixpkgs.legacyPackages.${system});
      parts = pkgs: import ./nix { inherit pkgs; src = self; };
    in
    {
      # nix run                      the desktop, in a DOSBox window
      # nix run .#chat-server        the chat server (docs/CHAT.md)
      # nix run .#chat-relay         the host relay for the serial port
      # nix run .#test               every test, headless
      # nix run .#snuggle -- --help  the tool: build, docs, test, shot
      # nix flake check              unit tests and docs (the QBasic groups run with `nix run .#test`)
      packages = forAll (pkgs: (parts pkgs).packages);
      apps = forAll (pkgs: (parts pkgs).apps);
      checks = forAll (pkgs: (parts pkgs).checks);
      devShells = forAll (pkgs: { default = (parts pkgs).devShell; });
      formatter = forAll (pkgs: pkgs.nixpkgs-fmt);
    };
}
