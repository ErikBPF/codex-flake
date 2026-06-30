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
            home.username = "codex-test";
            home.homeDirectory = "/home/codex-test";
            home.stateVersion = "25.11";
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
        package.enable = false;
        rtk.enable = true;
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

  lint = pkgs.runCommand "codex-profile-lint" {} ''
    cd ${self}
    ${pkgs.alejandra}/bin/alejandra --check .
    ${pkgs.statix}/bin/statix check . -i '.direnv/*' 2>&1 || true
    ${pkgs.deadnix}/bin/deadnix . 2>&1 || true
    touch "$out"
  '';
}
