{
  description = "Home Manager module for OpenAI Codex global agent profile files";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";

    flake-parts = {
      url = "github:hercules-ci/flake-parts";
      inputs.nixpkgs-lib.follows = "nixpkgs";
    };

    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = inputs @ {
    self,
    flake-parts,
    ...
  }:
    flake-parts.lib.mkFlake {inherit inputs;} {
      systems = ["x86_64-linux" "aarch64-linux" "x86_64-darwin" "aarch64-darwin"];

      perSystem = {
        pkgs,
        system,
        ...
      }: let
        codexPackage = pkgs.callPackage ./packages/codex/package.nix {};
      in {
        packages = {
          default = codexPackage;
          codex = codexPackage;
        };

        apps = {
          default = {
            type = "app";
            program = "${codexPackage}/bin/codex";
            meta.description = "Run packaged Codex";
          };
          codex = {
            type = "app";
            program = "${codexPackage}/bin/codex";
            meta.description = "Run packaged Codex";
          };
          update = {
            type = "app";
            program = toString (pkgs.writeShellScript "codex-flake-update" ''
              set -euo pipefail
              cd "$(${pkgs.git}/bin/git rev-parse --show-toplevel 2>/dev/null \
                    || { echo "must be run from inside the flake repo" >&2; exit 1; })"
              exec ${pkgs.bash}/bin/bash ./scripts/update-codex.sh "$@"
            '');
            meta.description = "Check + apply latest upstream Codex release";
          };
          update-check = {
            type = "app";
            program = toString (pkgs.writeShellScript "codex-flake-update-check" ''
              set -euo pipefail
              cd "$(${pkgs.git}/bin/git rev-parse --show-toplevel 2>/dev/null \
                    || { echo "must be run from inside the flake repo" >&2; exit 1; })"
              exec ${pkgs.bash}/bin/bash ./scripts/update-codex.sh --check
            '');
            meta.description = "Exit 1 if upstream Codex is newer than the package";
          };
        };

        checks = import ./checks.nix {
          inherit inputs pkgs self system;
        };

        formatter = pkgs.alejandra;

        devShells.default = pkgs.mkShellNoCC {
          name = "codex-flake-dev";
          packages = with pkgs; [
            alejandra
            deadnix
            jq
            just
            nil
            nix-update
            statix
          ];
        };
      };

      flake = {
        homeManagerModules = {
          default = import ./modules/home-manager.nix;
          codex-profile = self.homeManagerModules.default;
          withPackage = {pkgs, ...}: {
            imports = [self.homeManagerModules.default];
            programs.codex-profile.package.package = self.packages.${pkgs.stdenv.hostPlatform.system}.codex;
          };
        };

        overlays.default = _final: prev: {
          codex-latest = self.packages.${prev.system}.codex;
        };

        templates.default = {
          path = ./templates/default;
          description = "Minimal Home Manager flake using codex-flake";
          welcomeText = ''
            codex-flake template scaffolded.

            1. Edit flake.nix and set `programs.codex-profile.agents.extraText`.
            2. Build with `home-manager switch --flake .#me`.
            3. Probe with `codex exec`.
          '';
        };

        templates.minimal = self.templates.default;
      };
    };
}
