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
    hash = "sha256-NUcynowuvP6xA1W4kuRjI8iW4TH9uR40Wsrvl4U99fk=";
  };

  nativeBuildInputs = [unzip];

  sourceRoot = "Ghostty.app";

  installPhase = ''
    runHook preInstall

    mkdir -p "$out/Applications/Ghostty.app"
    cp -R . "$out/Applications/Ghostty.app"

    runHook postInstall
  '';

  passthru = {
    updateScript = nix-update-script {
      extraArgs = ["--version=skip"];
    };
  };

  meta = {
    description = " 👻 Ghostty is a fast, feature-rich, and cross-platform terminal emulator that uses platform-native UI and GPU acceleration. ";
    homepage = "https://ghostty.org";
    license = lib.licenses.mit;
    platforms = ["aarch64-darwin"];
    sourceProvenance = [lib.sourceTypes.binaryNativeCode];
    maintainers = [];
  };
})
