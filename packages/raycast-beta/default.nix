{
  lib,
  stdenvNoCC,
  fetchurl,
  undmg,
  nix-update-script,
}:
stdenvNoCC.mkDerivation (_finalAttrs: {
  pname = "raycast-beta";
  version = "0.71.2.0";

  src = fetchurl {
    url = "https://x-r2.raycast-releases.com/Raycast_Beta_0.71.2.0_e5ed8d68ad_arm64.dmg";
    hash = "sha256-U42RaEIdZVXsG77AedBBeJ5w57VvVVQzaiFW198Jw7A=";
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
