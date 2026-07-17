{
  lib,
  stdenvNoCC,
  fetchurl,
  undmg,
  nix-update-script,
}:
stdenvNoCC.mkDerivation (_finalAttrs: {
  pname = "raycast-beta";
  version = "0.69.0.0";

  src = fetchurl {
    url = "https://x-r2.raycast-releases.com/Raycast_Beta_0.69.0.0_76da0f08ae_arm64.dmg";
    hash = "sha256-0QF8o8fUEl7CyBnfKTEMaEA4dsSaCo/MiTxKH5+2fr8=";
  };

  nativeBuildInputs = [undmg];

  sourceRoot = "Raycast Beta.app";

  installPhase = ''
    runHook preInstall

    mkdir -p "$out/Applications/Raycast Beta.app"
    cp -R . "$out/Applications/Raycast Beta.app"

    runHook postInstall
  '';

  passthru = {
    updateScript = nix-update-script {};
    renovate.datasource = "custom.raycast-beta";
  };

  meta = {
    description = "Control your tools with a few keystrokes - beta release";
    homepage = "https://raycast.com";
    license = lib.licenses.unfree;
    platforms = ["aarch64-darwin"];
    sourceProvenance = [lib.sourceTypes.binaryNativeCode];
    maintainers = [];
  };
})
