{
  lib,
  stdenvNoCC,
  fetchurl,
  undmg,
  nix-update-script,
}:
stdenvNoCC.mkDerivation (_finalAttrs: {
  pname = "raycast-beta";
  version = "0.66.1.0";

  src = fetchurl {
    url = "https://x-r2.raycast-releases.com/Raycast_Beta_0.66.1.0_c1e0ac7b6f_arm64.dmg";
    hash = "sha256-WsstfZdAnQu5WClTKRoMJpfziLP7zK/OEwlp6iMelEY=";
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
