{
  lib,
  stdenv,
  darwin,
}:

stdenv.mkDerivation {
  pname = "defaultbrowser";
  version = "1.0.0";

  src = ./src;

  buildInputs = [ ];

  buildPhase = ''
    make
  '';

  installPhase = ''
    mkdir -p $out/bin
    cp defaultbrowser $out/bin/
  '';

  meta = with lib; {
    description = "Utility to set the default browser on macOS";
    homepage = "https://github.com/kerma/defaultbrowser";
    platforms = platforms.darwin;
  };
}
