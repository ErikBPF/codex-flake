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
  version = "0.144.1";

  hashes = {
    x86_64-linux = "sha256-hAka4gxl/MfUEg25fRvVfX/435x2Cft4HHjC671PWig=";
    aarch64-linux = "sha256-ufjvX5jkbO1Nu9N1akIj4+4pmkV/9IijMFvqRV2otbg=";
    x86_64-darwin = "sha256-DqctIceUUENC1f4NXQV7AiHApC9L30pIuVryQ68rDA4=";
    aarch64-darwin = "sha256-iOcqyL0wgV99GOYtrDM9wgzjrRy6lL4WSaGXfdm/27g=";
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
