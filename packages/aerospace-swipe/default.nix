{
  lib,
  stdenv,
  fetchFromGitHub,
  pkgs,
  ...
}:

stdenv.mkDerivation {

    pname = "aerospace-swipe";
    version = "1.0.0";

    src = fetchFromGitHub {
      owner = "acsandmann";
      repo = "aerospace-swipe";
      hash = "sha256-ZLaE/CuUgpWXrmV0cKLI8L9R92REECxWcpOwofMDMx4=";
      rev =  "1845e0e99c4c4bb34453253189a437a698ddbdc8";
    };

    nativeBuildInputs = [
        pkgs.apple-sdk
    ];

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
