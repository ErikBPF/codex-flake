# codex-flake

[![FlakeHub](https://img.shields.io/endpoint?url=https://flakehub.com/f/ErikBPF/codex-flake/badge)](https://flakehub.com/flake/ErikBPF/codex-flake)

Home Manager module for global OpenAI Codex profile files.

## What it manages

- `~/.codex/AGENTS.md`
- `~/.codex/RTK.md` when RTK guidance is enabled
- `~/.codex/config.toml` only when explicitly enabled
- `pkgs.codex` in `home.packages` only when explicitly enabled
- optionally, this flake's faster-moving `codex` package

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
            package.enable = true;
          };
        }
      ];
    };
  };
}
```

## Package update lanes

The default module is conservative: `programs.codex-profile.package.package`
defaults to the consumer's `pkgs.codex`.

For a faster Codex package lane, import the package-aware module:

```nix
{
  imports = [codex-flake.homeManagerModules.withPackage];

  programs.codex-profile = {
    enable = true;
    package.enable = true;
  };
}
```

That package follows upstream `openai/codex` Rust releases and is updated by:

```bash
nix run .#update-check
nix run .#update
```

The fast package lane currently supports `x86_64-linux` only and checks for
updates daily. ARM and Darwin can be added later as advisory builds once runner
availability, cache hit rate, and build time are known.

TODO: check whether CI cache/storage is cheap enough to make the full Codex
package build a required publishing gate.

Trust modes:

- **Profile-only:** use the default module and your own `pkgs.codex`.
- **Rolling package:** use `homeManagerModules.withPackage` with the FlakeHub
  wildcard input.
- **Pinned package:** pin this flake to a commit or exact FlakeHub release before
  importing `withPackage`.

## Why RTK is inline by default

Codex loads global `~/.codex/AGENTS.md`, but observed behavior did not expand an
`@/home/user/.codex/RTK.md` include into model context. RTK guidance is therefore
inlined into `AGENTS.md` when enabled. `RTK.md` is still rendered as a reference
file for humans and external tooling.

By default the module uses reduced Codex-focused RTK guidance. To generate RTK
guidance from RTK itself, provide an RTK package and opt in:

```nix
programs.codex-profile.rtk = {
  enable = true;
  source = "generated";
  package = yourRtkPackage;
};
```

## Config policy

`~/.codex/config.toml` is mutable user config and lives next to `auth.json`,
session files, history, cache, and state databases. This module leaves it alone
unless `programs.codex-profile.configFile.enable = true`.
