{
  lib,
  stdenv,
  fetchFromGitHub,
}:

stdenv.mkDerivation {

    pname = "aerospace-swipe";
    version = "1.0.0";

    src = fetchFromGitHub {
      owner = "acsandmann";
      repo = "aerospace-swipe";
      hash = "sha256-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=";
    };

    buildPhase = ''
      make
    '';

    installPhase = ''
        make install
    '';


    meta = with lib; {
        description = "switch workspaces in AeroSpace with trackpad swipes";
        homepage = "https://github.com/acsandmann/aerospace-swipe";
        platforms = platforms.darwin;
    };
}
