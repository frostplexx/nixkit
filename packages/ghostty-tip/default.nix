{
  lib,
  stdenvNoCC,
  fetchurl,
  undmg,
  nix-update-script,
}:
stdenvNoCC.mkDerivation (_finalAttrs: {
  pname = "ghostty-tip";
  version = "tip";

  src = fetchurl {
    url = "https://github.com/ghostty-org/ghostty/releases/download/tip/Ghostty.dmg";
    hash = "sha256-qPDFXXRrXMXRhRw+F14Sy/nx/fk20NkR7VQn/+a+2gQ=";
  };

  nativeBuildInputs = [undmg];

  sourceRoot = "Ghostty.app";

  installPhase = ''
    runHook preInstall

    mkdir -p "$out/Applications/Ghostty.app"
    cp -R . "$out/Applications/Ghostty.app"

    runHook postInstall
  '';

  passthru = {
    updateScript = nix-update-script {};
    renovate.datasource = "custom.ghostty-tip";
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
