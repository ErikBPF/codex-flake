{
  lib,
  stdenv,
  callPackage,
  rustPlatform,
  fetchFromGitHub,
  installShellFiles,
  bubblewrap,
  clang,
  cmake,
  gitMinimal,
  libcap,
  libclang,
  librusty_v8 ?
    callPackage ./librusty_v8.nix {
      inherit (callPackage ./fetchers.nix {}) fetchLibrustyV8;
    },
  livekit-libwebrtc,
  lld,
  makeBinaryWrapper,
  nix-update-script,
  pkg-config,
  openssl,
  ripgrep,
  versionCheckHook,
  installShellCompletions ? stdenv.buildPlatform.canExecute stdenv.hostPlatform,
}:
rustPlatform.buildRustPackage (finalAttrs: {
  pname = "codex";
  version = "0.142.4";

  src = fetchFromGitHub {
    owner = "openai";
    repo = "codex";
    tag = "rust-v${finalAttrs.version}";
    hash = "sha256-cYkdLy0+KMjcx0k7IDACsiTK3ZZks6cmwbeDMheN6WY=";
  };

  sourceRoot = "${finalAttrs.src.name}/codex-rs";

  cargoHash = "sha256-1gDiCB3Nf/0aIm+EoL3g9C0xbCi3cv6TfH5VytjJpOY=";

  __structuredAttrs = true;

  cargoBuildFlags = [
    "--package"
    "codex-cli"
  ];
  cargoCheckFlags = [
    "--package"
    "codex-cli"
  ];

  postPatch = ''
    substituteInPlace $cargoDepsCopy/*/webrtc-sys-*/build.rs \
      --replace-fail "cargo:rustc-link-lib=static=webrtc" "cargo:rustc-link-lib=dylib=webrtc"
    substituteInPlace Cargo.toml \
      --replace-fail 'lto = "thin"' "" \
      --replace-fail 'codegen-units = 4' ""
  '';

  nativeBuildInputs = [
    clang
    cmake
    gitMinimal
    installShellFiles
    makeBinaryWrapper
    pkg-config
  ];

  buildInputs =
    [
      libclang
      openssl
    ]
    ++ lib.optionals stdenv.hostPlatform.isLinux [
      libcap
    ];

  env =
    {
      LIBCLANG_PATH = "${lib.getLib libclang}/lib";
      LK_CUSTOM_WEBRTC = lib.getDev livekit-libwebrtc;
      NIX_CFLAGS_COMPILE = toString (
        lib.optionals stdenv.cc.isGNU [
          "-Wno-error=stringop-overflow"
        ]
        ++ lib.optionals stdenv.cc.isClang [
          "-Wno-error=character-conversion"
        ]
      );
      RUSTY_V8_ARCHIVE = librusty_v8;
    }
    // lib.optionalAttrs stdenv.hostPlatform.isDarwin {
      NIX_CFLAGS_LINK = "-fuse-ld=${lib.getExe' lld "ld64.lld"}";
    };

  doCheck = false;

  postInstall = lib.optionalString installShellCompletions ''
    installShellCompletion --cmd codex \
      --bash <($out/bin/codex completion bash) \
      --fish <($out/bin/codex completion fish) \
      --zsh <($out/bin/codex completion zsh)
  '';

  postFixup = ''
    wrapProgram $out/bin/codex --prefix PATH : ${
      lib.makeBinPath ([ripgrep] ++ lib.optionals stdenv.hostPlatform.isLinux [bubblewrap])
    }
  '';

  doInstallCheck = true;
  nativeInstallCheckInputs = [versionCheckHook];

  passthru = {
    updateScript = nix-update-script {
      extraArgs = [
        "--use-github-releases"
        "--version-regex"
        "^rust-v(\\d+\\.\\d+\\.\\d+)$"
      ];
    };
  };

  meta = {
    description = "Lightweight coding agent that runs in your terminal";
    homepage = "https://github.com/openai/codex";
    changelog = "https://raw.githubusercontent.com/openai/codex/refs/tags/rust-v${finalAttrs.version}/CHANGELOG.md";
    license = lib.licenses.asl20;
    mainProgram = "codex";
    platforms = ["x86_64-linux"];
  };
})
