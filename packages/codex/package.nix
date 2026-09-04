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
  version = "0.153.2";

  hashes = {
    x86_64-linux = "sha256-4Q+gzueOnwvTlYgPA/1P0ifZA8p69km7wI0WSRAekiU=";
    aarch64-linux = "sha256-o7+vS2L8sX4KAzjf4FAkE93OCrGzkChnk5BTnEXSxuM=";
    x86_64-darwin = "sha256-bjh25/Tt/y497lReHTsjNIZnkajfzn4leJv2eZNVpOo=";
    aarch64-darwin = "sha256-KH4t0Km7+1hYGwqRUDmUWLTwlOpCyvAoYPHoy1ogKgs=";
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
