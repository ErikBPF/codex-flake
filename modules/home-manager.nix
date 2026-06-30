{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.programs.codex-profile;
  tomlFormat = pkgs.formats.toml {};
  inherit (lib) mkEnableOption mkIf mkOption optional optionalString types;

  defaultRtkText = ''
    # RTK - Rust Token Killer (Codex CLI)

    **Usage**: Token-optimized CLI proxy for shell commands.

    ## Rule

    Prefer `rtk` for read-only or high-output shell commands when RTK has a
    matching subcommand, especially `git`, `ls`, `tree`, `read`, `grep`,
    `diff`, `test`, `pytest`, `cargo`, `npm`, `npx`, `tsc`, `lint`, and
    `playwright`.

    Use `rtk proxy <cmd>` for unsupported read-only commands when token
    tracking matters.

    Do not prefix state-changing commands with `rtk` just to satisfy this
    guideline. Use the raw command when exact shell behavior, quoting,
    redirection, sandboxing, approval prompts, or side effects matter more
    than output filtering.

    Examples:

    ```bash
    rtk git status
    rtk cargo test
    rtk npm run build
    rtk pytest -q
    rtk proxy which rtk
    ```

    ## Meta Commands

    ```bash
    rtk gain            # Token savings analytics
    rtk gain --history  # Recent command savings history
    rtk proxy <cmd>     # Run raw command without filtering
    ```

    ## Verification

    ```bash
    rtk --version
    rtk gain
    rtk init -g --codex --show
    ```
  '';

  cavemanText = ''
    ## Default Response Style

    Use caveman ${cfg.style.level} style by default for assistant prose:

    - terse, high-signal technical language
    - no pleasantries, filler, or decorative recap
    - fragments are fine when meaning stays clear
    - keep code, file paths, commands, API names, and exact errors unchanged
    - preserve the user's language

    Drop compression when it could make security warnings, irreversible-action
    confirmations, or ordered multi-step instructions ambiguous. Resume terse
    style after the clear part.

    Stop using this style only when the user asks for normal mode or explicitly
    requests a different tone.
  '';

  styleText =
    if cfg.style.text != null
    then cfg.style.text
    else if cfg.style.name == "caveman"
    then cavemanText
    else "";

  reducedRtkText = defaultRtkText;

  generatedRtkFile =
    if cfg.rtk.package == null
    then throw "programs.codex-profile.rtk.source = \"generated\" requires programs.codex-profile.rtk.package"
    else
      pkgs.runCommand "codex-rtk-generated.md" {
        nativeBuildInputs = [cfg.rtk.package];
      } ''
        rtk init -g --codex --show > "$out"
      '';

  rtkText =
    if cfg.rtk.text != null
    then cfg.rtk.text
    else reducedRtkText;

  rtkFile =
    if cfg.rtk.source == "generated" && cfg.rtk.text == null
    then generatedRtkFile
    else pkgs.writeText "codex-rtk.md" rtkText;

  agentsText =
    lib.concatStringsSep "\n\n"
    (lib.filter (text: text != "") [
      cfg.agents.preamble
      (optionalString (cfg.rtk.enable && cfg.rtk.inline) rtkText)
      (optionalString cfg.style.enable styleText)
      cfg.agents.extraText
    ]);

  agentsFile =
    if cfg.rtk.source == "generated" && cfg.rtk.text == null && cfg.rtk.inline
    then
      pkgs.runCommand "codex-agents-generated.md" {} ''
        cat ${pkgs.writeText "codex-agents-preamble.md" cfg.agents.preamble} > "$out"
        printf '\n\n' >> "$out"
        cat ${generatedRtkFile} >> "$out"
        printf '\n\n' >> "$out"
        cat ${pkgs.writeText "codex-agents-style.md" styleText} >> "$out"
        printf '\n\n' >> "$out"
        cat ${pkgs.writeText "codex-agents-extra.md" cfg.agents.extraText} >> "$out"
      ''
    else pkgs.writeText "codex-agents.md" agentsText;
in {
  options.programs.codex-profile = {
    enable = mkEnableOption "Codex global profile files";

    package = {
      enable = mkOption {
        type = types.bool;
        default = false;
        description = "Install the Codex package into `home.packages`.";
      };

      package = mkOption {
        type = types.package;
        default = pkgs.codex;
        defaultText = "pkgs.codex";
        description = "Codex package to install when `package.enable` is true.";
      };
    };

    agents = {
      enable = mkOption {
        type = types.bool;
        default = true;
        description = "Manage `~/.codex/AGENTS.md`.";
      };

      preamble = mkOption {
        type = types.lines;
        default = ''
          # Codex Defaults

          These instructions apply to every Codex session for this user.
        '';
        description = "Text rendered at the start of `AGENTS.md`.";
      };

      extraText = mkOption {
        type = types.lines;
        default = "";
        description = "Additional text appended to `AGENTS.md`.";
      };
    };

    rtk = {
      enable = mkOption {
        type = types.bool;
        default = false;
        description = "Render RTK guidance for Codex.";
      };

      inline = mkOption {
        type = types.bool;
        default = true;
        description = "Inline RTK guidance into `AGENTS.md` instead of relying on `@RTK.md` includes.";
      };

      source = mkOption {
        type = types.enum ["reduced" "generated"];
        default = "reduced";
        description = ''
          RTK guidance source. `reduced` uses the built-in Codex-focused
          guidance. `generated` runs `rtk init -g --codex --show` from
          `programs.codex-profile.rtk.package`.
        '';
      };

      package = mkOption {
        type = types.nullOr types.package;
        default = null;
        description = "RTK package used when `rtk.source = \"generated\"`.";
      };

      text = mkOption {
        type = types.nullOr types.lines;
        default = null;
        description = "Override RTK guidance text.";
      };
    };

    rtkFile = {
      enable = mkOption {
        type = types.bool;
        default = true;
        description = "Manage `~/.codex/RTK.md` when RTK is enabled.";
      };
    };

    style = {
      enable = mkOption {
        type = types.bool;
        default = false;
        description = "Render default response style guidance into `AGENTS.md`.";
      };

      name = mkOption {
        type = types.enum ["caveman" "custom"];
        default = "caveman";
        description = "Built-in style guidance to render when `style.text` is null.";
      };

      level = mkOption {
        type = types.enum ["lite" "full" "ultra"];
        default = "full";
        description = "Caveman style intensity.";
      };

      text = mkOption {
        type = types.nullOr types.lines;
        default = null;
        description = "Custom response style guidance.";
      };
    };

    configFile = {
      enable = mkOption {
        type = types.bool;
        default = false;
        description = ''
          Manage `~/.codex/config.toml`. Disabled by default because Codex
          config is mutable and lives next to auth, session, cache, and history
          state.
        '';
      };

      settings = mkOption {
        type = tomlFormat.type;
        default = {};
        description = "TOML settings rendered to `~/.codex/config.toml` when enabled.";
      };
    };
  };

  config = mkIf cfg.enable {
    home.packages = optional cfg.package.enable cfg.package.package;

    home.file.".codex/AGENTS.md" = mkIf cfg.agents.enable {
      source = agentsFile;
    };

    home.file.".codex/RTK.md" = mkIf (cfg.rtk.enable && cfg.rtkFile.enable) {
      source = rtkFile;
    };

    home.file.".codex/config.toml" = mkIf cfg.configFile.enable {
      source = tomlFormat.generate "codex-config.toml" cfg.configFile.settings;
    };
  };
}
