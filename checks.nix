{
  inputs,
  pkgs,
  self,
  system,
}: let
  hmConfig = extraModules:
    inputs.home-manager.lib.homeManagerConfiguration {
      inherit pkgs;
      modules =
        [
          self.homeManagerModules.default
          {
            home = {
              username = "codex-test";
              homeDirectory = "/home/codex-test";
              stateVersion = "25.11";
            };
          }
        ]
        ++ extraModules;
    };

  enabled = hmConfig [
    {
      programs.codex-profile = {
        enable = true;
        package.enable = false;
        rtk.enable = true;
        style.enable = true;
      };
    }
  ];

  withConfig = hmConfig [
    {
      programs.codex-profile = {
        enable = true;
        package.enable = false;
        rtk.enable = true;
        configFile = {
          enable = true;
          settings = {
            approvals_reviewer = "auto_review";
            features.terminal_resize_reflow = true;
          };
        };
      };
    }
  ];

  withoutConfig = hmConfig [
    {
      programs.codex-profile = {
        enable = true;
        rtk.enable = true;
      };
    }
  ];

  withoutRtkFile = hmConfig [
    {
      programs.codex-profile = {
        enable = true;
        rtk.enable = false;
      };
    }
  ];

  withoutAgents = hmConfig [
    {
      programs.codex-profile = {
        enable = true;
        agents.enable = false;
        rtk.enable = true;
      };
    }
  ];

  fakeCodex = pkgs.writeShellApplication {
    name = "codex";
    text = ''
      printf '%s\n' "codex 0.0.0-test"
    '';
  };

  withFakePackage = hmConfig [
    {
      programs.codex-profile = {
        enable = true;
        package = {
          enable = true;
          package = fakeCodex;
        };
      };
    }
  ];

  withSelfPackage = inputs.home-manager.lib.homeManagerConfiguration {
    inherit pkgs;
    modules = [
      self.homeManagerModules.withPackage
      {
        home = {
          username = "codex-test";
          homeDirectory = "/home/codex-test";
          stateVersion = "25.11";
        };
        programs.codex-profile = {
          enable = true;
          package.enable = true;
        };
      }
    ];
  };

  fakeRtk = pkgs.writeShellApplication {
    name = "rtk";
    text = ''
      if [ "$*" = "init -g --codex --show" ]; then
        printf '%s\n' "# Generated RTK"
        printf '%s\n' "Use generated Codex RTK guidance."
        exit 0
      fi
      echo "unexpected args: $*" >&2
      exit 2
    '';
  };

  mockCodexReleases = pkgs.writeText "codex-releases.json" ''
    [
      {
        "tag_name": "npm-v9.9.9",
        "html_url": "https://example.invalid/npm",
        "draft": false,
        "prerelease": false,
        "published_at": "2030-01-01T00:00:00Z",
        "created_at": "2030-01-01T00:00:00Z",
        "assets": []
      },
      {
        "tag_name": "rust-v0.145.0",
        "html_url": "https://example.invalid/incomplete",
        "draft": false,
        "prerelease": false,
        "published_at": "2029-01-01T00:00:00Z",
        "created_at": "2029-01-01T00:00:00Z",
        "assets": [
          {"name": "codex-x86_64-unknown-linux-musl.tar.gz"}
        ]
      },
      {
        "tag_name": "rust-v0.144.1",
        "html_url": "https://example.invalid/rust-v0.144.1",
        "draft": false,
        "prerelease": false,
        "published_at": "2028-01-01T00:00:00Z",
        "created_at": "2028-01-01T00:00:00Z",
        "assets": [
          {"name": "codex-x86_64-unknown-linux-musl.tar.gz"},
          {"name": "codex-aarch64-unknown-linux-musl.tar.gz"},
          {"name": "codex-x86_64-apple-darwin.tar.gz"},
          {"name": "codex-aarch64-apple-darwin.tar.gz"}
        ]
      }
    ]
  '';

  mockUpdateNix = pkgs.writeShellApplication {
    name = "nix";
    text = ''
      if [ "$*" = "eval --raw .#codex.version" ]; then
        printf '%s\n' "0.1.0"
        exit 0
      fi
      printf 'unexpected nix args: %s\n' "$*" >&2
      exit 2
    '';
  };

  mockUpdateGh = pkgs.writeShellApplication {
    name = "gh";
    text = ''
      cat ${mockCodexReleases}
    '';
  };

  generated = hmConfig [
    {
      programs.codex-profile = {
        enable = true;
        package.enable = false;
        rtk = {
          enable = true;
          source = "generated";
          package = fakeRtk;
        };
      };
    }
  ];
in {
  module-render = pkgs.runCommand "codex-profile-module-render" {} ''
    agents='${enabled.config.home.file.".codex/AGENTS.md".source}'
    rtk='${enabled.config.home.file.".codex/RTK.md".source}'

    grep -q "RTK - Rust Token Killer (Codex CLI)" "$agents"
    grep -q "Prefer \`rtk\` for read-only or high-output shell commands" "$agents"
    grep -q "Use caveman full style" "$agents"
    grep -q "RTK - Rust Token Killer (Codex CLI)" "$rtk"

    touch "$out"
  '';

  config-opt-in = pkgs.runCommand "codex-profile-config-opt-in" {} ''
    config='${withConfig.config.home.file.".codex/config.toml".source}'
    grep -q 'approvals_reviewer = "auto_review"' "$config"
    grep -q '\[features\]' "$config"
    grep -q 'terminal_resize_reflow = true' "$config"

    touch "$out"
  '';

  config-default-off = assert !(builtins.hasAttr ".codex/config.toml" withoutConfig.config.home.file);
    pkgs.runCommand "codex-profile-config-default-off" {} ''
      touch "$out"
    '';

  package-default-off = assert !(builtins.any (pkg: builtins.toString pkg == builtins.toString pkgs.codex) withoutConfig.config.home.packages);
    pkgs.runCommand "codex-profile-package-default-off" {} ''
      touch "$out"
    '';

  rtk-file-off = assert !(builtins.hasAttr ".codex/RTK.md" withoutRtkFile.config.home.file);
    pkgs.runCommand "codex-profile-rtk-file-off" {} ''
      touch "$out"
    '';

  agents-file-off = assert !(builtins.hasAttr ".codex/AGENTS.md" withoutAgents.config.home.file);
    pkgs.runCommand "codex-profile-agents-file-off" {} ''
      touch "$out"
    '';

  package-opt-in = assert builtins.any (pkg: builtins.toString pkg == builtins.toString fakeCodex) withFakePackage.config.home.packages;
    pkgs.runCommand "codex-profile-package-opt-in" {} ''
      touch "$out"
    '';

  self-package-module = assert builtins.any (pkg: builtins.toString pkg == builtins.toString self.packages.${system}.codex) withSelfPackage.config.home.packages;
    pkgs.runCommand "codex-profile-self-package-module" {} ''
      touch "$out"
    '';

  codex-version = pkgs.runCommand "codex-version" {} ''
    ${self.packages.${system}.codex}/bin/codex --version | grep -F '${self.packages.${system}.codex.version}'
    touch "$out"
  '';

  update-script-latest-selection =
    pkgs.runCommand "codex-update-script-latest-selection" {
      nativeBuildInputs = [pkgs.jq];
    } ''
      cd ${self}
      set +e
      output="$(PATH="${mockUpdateNix}/bin:${mockUpdateGh}/bin:${pkgs.jq}/bin:${pkgs.bash}/bin:${pkgs.coreutils}/bin:${pkgs.gnused}/bin" ${pkgs.bash}/bin/bash ./scripts/update-codex.sh --check 2>&1)"
      status=$?
      set -e
      printf '%s\n' "$output"
      [ "$status" -eq 1 ]
      printf '%s\n' "$output" | grep -F "latest:  0.144.1"
      printf '%s\n' "$output" | grep -F "release: https://example.invalid/rust-v0.144.1"
      printf '%s\n' "$output" | grep -F "update available: 0.1.0 -> 0.144.1"
      touch "$out"
    '';

  generated-rtk = pkgs.runCommand "codex-profile-generated-rtk" {} ''
    agents='${generated.config.home.file.".codex/AGENTS.md".source}'
    rtk='${generated.config.home.file.".codex/RTK.md".source}'

    grep -q "Generated RTK" "$agents"
    grep -q "Generated RTK" "$rtk"

    touch "$out"
  '';

  lint = pkgs.runCommand "codex-profile-lint" {} ''
    cd ${self}
    ${pkgs.alejandra}/bin/alejandra --check .
    ${pkgs.statix}/bin/statix check . -i '.direnv/*'
    ${pkgs.deadnix}/bin/deadnix --fail .
    touch "$out"
  '';
}
