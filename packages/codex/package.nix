# Official prebuilt Codex binaries from OpenAI's GitHub releases (the same
# artifacts the @openai/codex npm installer downloads; each has a .sigstore
# bundle upstream). Linux binaries are static musl — no patching needed.
# scripts/update-codex.sh bumps `version` and the `hashes` table; keep the
# one-line-per-platform format.
{
  lib,
  stdenvNoCC,
  fetchurl,
  installShellFiles,
  versionCheckHook,
  installShellCompletions ? stdenvNoCC.buildPlatform.canExecute stdenvNoCC.hostPlatform,
}: let
  version = "0.163.0";

  hashes = {
    x86_64-linux = "sha256-WCZGxr8FYesN5UD3/IW5EhsAkagmvG6Wgwt/FyISIYI=";
    aarch64-linux = "sha256-nY7PLRnT4YSHeYOQLWyF3kiziI3LcsOCqKDJdYRZJ/s=";
    x86_64-darwin = "sha256-DBgtYZTacAOUNnjch4ZrVLPe5xntr40JLzBK/7xrV9E=";
    aarch64-darwin = "sha256-sDRPwuQfFeAHEUflhpAIBHuP9L8sSoiXl107rj8QOzQ=";
  };

  triples = {
    x86_64-linux = "x86_64-unknown-linux-musl";
    aarch64-linux = "aarch64-unknown-linux-musl";
    x86_64-darwin = "x86_64-apple-darwin";
    aarch64-darwin = "aarch64-apple-darwin";
  };

  inherit (stdenvNoCC.hostPlatform) system;
  triple = triples.${system} or (throw "codex: unsupported system ${system}");
in
  stdenvNoCC.mkDerivation {
    pname = "codex";
    inherit version;

    src = fetchurl {
      url = "https://github.com/openai/codex/releases/download/rust-v${version}/codex-package-${triple}.tar.gz";
      hash = hashes.${system} or (throw "codex: no hash for ${system}");
    };

    # Keep the upstream package layout: Codex discovers its host and resources
    # relative to codex-package.json.
    sourceRoot = ".";

    nativeBuildInputs = [installShellFiles];

    dontConfigure = true;
    dontBuild = true;
    # Ship the official bytes as released.
    dontStrip = true;

    installPhase = ''
      runHook preInstall

      mkdir -p "$out"
      cp -R bin codex-package.json codex-path codex-resources "$out/"

      runHook postInstall
    '';

    postInstall = lib.optionalString installShellCompletions ''
      installShellCompletion --cmd codex \
        --bash <($out/bin/codex completion bash) \
        --fish <($out/bin/codex completion fish) \
        --zsh <($out/bin/codex completion zsh)
    '';

    doInstallCheck = true;
    nativeInstallCheckInputs = [versionCheckHook];

    meta = {
      description = "Lightweight coding agent that runs in your terminal";
      homepage = "https://github.com/openai/codex";
      changelog = "https://raw.githubusercontent.com/openai/codex/refs/tags/rust-v${version}/CHANGELOG.md";
      license = lib.licenses.asl20;
      sourceProvenance = with lib.sourceTypes; [binaryNativeCode];
      mainProgram = "codex";
      platforms = [
        "x86_64-linux"
        "aarch64-linux"
        "x86_64-darwin"
        "aarch64-darwin"
      ];
    };
  }
