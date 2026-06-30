{
  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";

    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    codex-flake = {
      url = "github:ErikBPF/codex-flake";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = {
    nixpkgs,
    home-manager,
    codex-flake,
    ...
  }: let
    system = "x86_64-linux";
    pkgs = import nixpkgs {inherit system;};
  in {
    homeConfigurations.me = home-manager.lib.homeManagerConfiguration {
      inherit pkgs;
      modules = [
        codex-flake.homeManagerModules.default
        {
          home.username = "me";
          home.homeDirectory = "/home/me";
          home.stateVersion = "25.11";

          programs.codex-profile = {
            enable = true;
            rtk.enable = true;
            style.enable = true;
          };
        }
      ];
    };
  };
}
