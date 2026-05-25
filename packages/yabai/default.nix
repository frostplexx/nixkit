{
  lib,
  stdenv,
  fetchFromGitHub,
  fetchpatch,
  apple-sdk_15,
  installShellFiles,
  versionCheckHook,
  xxd,
}:
stdenv.mkDerivation (finalAttrs: {
  pname = "yabai";
  version = "7.1.25";

  src = fetchFromGitHub {
    owner = "koekeishiya";
    repo = "yabai";
    rev = "v${finalAttrs.version}";
    hash = "sha256-61knfbahxxlJnVZy47347slsjUGiQUJyZh58G97SDkE=";
  };

  patches = [
    # Native tab handling for Terminal, Finder, etc.
    (fetchpatch {
      name = "native-tab-handling.patch";
      url = "https://github.com/CCMurphy-dev/yabai/commit/5f6ceef7d78530ee47f63e4ace61befb55038b2b.patch";
      hash = "sha256-xWOF7s9T2u0wpcFaawBpG0iD9wRXeajYu0j+agmtaYw=";
    })
    # Improved tab detection for Cmd+N and frame mismatches
    (fetchpatch {
      name = "improved-tab-detection.patch";
      url = "https://github.com/CCMurphy-dev/yabai/commit/9aba7710bd7374e6321856e6f62c94bb16105a44.patch";
      hash = "sha256-0Ph2z6XEiIemNAGMidpxEHeAotXJmIngKAXSMIbFHiE=";
    })
  ];

  nativeBuildInputs = [
    installShellFiles
    xxd
  ];

  buildInputs = [
    apple-sdk_15
  ];

  dontConfigure = true;
  enableParallelBuilding = false;

  postPatch = ''
    # Build only for current architecture (arm64)
    substituteInPlace makefile \
      --replace-fail " -arch x86_64 -arch arm64e" "" \
      --replace-fail " -arch x86_64 -arch arm64" ""
  '';

  installPhase = ''
    runHook preInstall

    mkdir -p $out/{bin,share/icons/hicolor/scalable/apps}
    cp ./bin/yabai $out/bin/yabai
    cp ./assets/icon/icon.svg $out/share/icons/hicolor/scalable/apps/yabai.svg
    installManPage ./doc/yabai.1

    runHook postInstall
  '';

  nativeInstallCheckInputs = [versionCheckHook];
  doInstallCheck = true;

  meta = {
    description = "Tiling window manager for macOS based on binary space partitioning";
    longDescription = ''
      yabai is a window management utility that is designed to work as an extension to the built-in
      window manager of macOS. yabai allows you to control your windows, spaces and displays freely
      using an intuitive command line interface and optionally set user-defined keyboard shortcuts
      using skhd and other third-party software.
    '';
    homepage = "https://github.com/asmvik/yabai";
    changelog = "https://github.com/asmvik/yabai/blob/v${finalAttrs.version}/CHANGELOG.md";
    license = lib.licenses.mit;
    platforms = ["aarch64-darwin"];
    mainProgram = "yabai";
    maintainers = with lib.maintainers; [
      cmacrae
      shardy
      khaneliman
    ];
    sourceProvenance = [lib.sourceTypes.fromSource];
  };
})
