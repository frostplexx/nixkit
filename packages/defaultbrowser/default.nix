{
  lib,
  stdenv,
  darwin,
}:

stdenv.mkDerivation {
  pname = "defaultbrowser";
  version = "1.0.0";

  src = ./src;

  buildInputs = lib.optionals stdenv.isDarwin [
    darwin.apple_sdk.frameworks.AppKit
    darwin.apple_sdk.frameworks.Foundation
  ];

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
