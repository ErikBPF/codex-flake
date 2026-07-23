# Official prebuilt Codex binaries from OpenAI's GitHub releases (the same
# artifacts the @openai/codex npm installer downloads; each has a .sigstore
# bundle upstream). Linux binaries are static musl — no patching needed.
# scripts/update-codex.sh bumps `version` and the `hashes` table; keep the
# one-line-per-platform format.
{
  lib,
  stdenvNoCC,
  fetchurl,
  bubblewrap,
  installShellFiles,
  makeBinaryWrapper,
  ripgrep,
  versionCheckHook,
  installShellCompletions ? stdenvNoCC.buildPlatform.canExecute stdenvNoCC.hostPlatform,
}: let
  version = "0.145.0";

  hashes = {
    x86_64-linux = "sha256-v68Tybo08q12TkqRbEnPcXeuujKc8PcZ4iJ1ZvyNZio=";
    aarch64-linux = "sha256-04T5C8hCRQtCvWdf7vBqEqRqOxypfvyyJWaycOShEic=";
    x86_64-darwin = "sha256-QhbXpAqknXS2X6uT0qhtLiWpAkgrgn29s/NXd3sJ+t8=";
    aarch64-darwin = "sha256-Byowpl8FZmc1iJ7w9gtW2xhq293p1cXMGmS+C1mFMP4=";
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
      url = "https://github.com/openai/codex/releases/download/rust-v${version}/codex-${triple}.tar.gz";
      hash = hashes.${system} or (throw "codex: no hash for ${system}");
    };

    # The tarball contains a single file: the codex-<triple> binary.
    sourceRoot = ".";

    nativeBuildInputs = [
      installShellFiles
      makeBinaryWrapper
    ];

    dontConfigure = true;
    dontBuild = true;
    # Ship the official bytes as released.
    dontStrip = true;

    installPhase = ''
      runHook preInstall

      install -Dm755 codex-${triple} $out/bin/codex
      wrapProgram $out/bin/codex --prefix PATH : ${
        lib.makeBinPath ([ripgrep] ++ lib.optionals stdenvNoCC.hostPlatform.isLinux [bubblewrap])
      }

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
