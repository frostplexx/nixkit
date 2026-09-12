{
  lib,
  stdenvNoCC,
  fetchurl,
  unzip,
  nix-update-script,
}:
stdenvNoCC.mkDerivation (_finalAttrs: {
  pname = "ghostty-tip";
  version = "tip";

  src = fetchurl {
    url = "https://github.com/ghostty-org/ghostty/releases/download/tip/ghostty-macos-universal.zip";
    hash = "sha256-VWAbqltm02oRK4B7qF1b6X5wMYZ5c0casJPHCisP4S0=";
  };

  nativeBuildInputs = [unzip];

  sourceRoot = "Ghostty.app";

  installPhase = ''
    runHook preInstall

    mkdir -p "$out/Applications/Ghostty.app"
    cp -R . "$out/Applications/Ghostty.app"

    mkdir -p "$out/bin"
    ln -s "$out/Applications/Ghostty.app/Contents/MacOS/ghostty" "$out/bin/ghostty"

    runHook postInstall
  '';

  passthru = {
    updateScript = nix-update-script {
      extraArgs = ["--version=skip"];
    };
  };

  meta = {
    mainProgram = "ghostty";
    description = " 👻 Ghostty is a fast, feature-rich, and cross-platform terminal emulator that uses platform-native UI and GPU acceleration. ";
    homepage = "https://ghostty.org";
    license = lib.licenses.mit;
    platforms = ["aarch64-darwin"];
    sourceProvenance = [lib.sourceTypes.binaryNativeCode];
    maintainers = [];
  };
})
