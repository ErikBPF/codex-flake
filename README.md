# codex-flake

[![FlakeHub](https://img.shields.io/endpoint?url=https://flakehub.com/f/ErikBPF/codex-flake/badge)](https://flakehub.com/flake/ErikBPF/codex-flake)

Home Manager module for global OpenAI Codex profile files.

## What it manages

- `~/.codex/AGENTS.md`
- `~/.codex/RTK.md` when RTK guidance is enabled
- `~/.codex/config.toml` only when explicitly enabled
- `pkgs.codex` in `home.packages` by default

It does not manage auth, logs, sessions, history, shell snapshots, cache, or
state databases.

## Usage

FlakeHub input:

```nix
{
  inputs.codex-flake.url = "https://flakehub.com/f/ErikBPF/codex-flake/*";
}
```

GitHub input:

```nix
{
  inputs.codex-flake = {
    url = "github:ErikBPF/codex-flake";
    inputs.nixpkgs.follows = "nixpkgs";
  };

  outputs = {codex-flake, ...}: {
    homeConfigurations.me = home-manager.lib.homeManagerConfiguration {
      modules = [
        codex-flake.homeManagerModules.default
        {
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
```

## Why RTK is inline by default

Codex loads global `~/.codex/AGENTS.md`, but observed behavior did not expand an
`@/home/user/.codex/RTK.md` include into model context. RTK guidance is therefore
inlined into `AGENTS.md` when enabled. `RTK.md` is still rendered as a reference
file for humans and external tooling.

## Config policy

`~/.codex/config.toml` is mutable user config and lives next to `auth.json`,
session files, history, cache, and state databases. This module leaves it alone
unless `programs.codex-profile.configFile.enable = true`.
