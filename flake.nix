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
      systems = ["x86_64-linux" "aarch64-linux" "aarch64-darwin"];

      perSystem = {
        pkgs,
        system,
        ...
      }: {
        checks = import ./checks.nix {
          inherit inputs pkgs self system;
        };

        formatter = pkgs.alejandra;

        devShells.default = pkgs.mkShellNoCC {
          name = "codex-flake-dev";
          packages = with pkgs; [
            alejandra
            deadnix
            just
            nil
            statix
          ];
        };
      };

      flake = {
        homeManagerModules.default = import ./modules/home-manager.nix;
        homeManagerModules.codex-profile = self.homeManagerModules.default;

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
