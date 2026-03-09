{
  lib,
  stdenv,
  swift,
}:

stdenv.mkDerivation {
  pname = "nixupdater";
  version = "1.0.0";

  src = ./src;

  nativeBuildInputs = [ swift ];

  buildPhase = ''
    make
  '';

installPhase = ''
    mkdir -p $out
    cp -r NixUpdater.app $out/NixUpdater.app
  '';

  meta = with lib; {
    description = "Menu bar app to check for updates on macOS";
    homepage = "https://github.com/kerma/defaultbrowser";
    platforms = platforms.darwin;
  };
}
