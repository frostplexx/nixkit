{
  lib,
  stdenv,
}:

stdenv.mkDerivation {
  pname = "hyperkey";
  version = "1.0.0";

  src = ./src;

  dontUnpack = true;

  installPhase = ''
    runHook preInstall
    mkdir -p $out/bin
    cp $src/hyperkey $out/bin/hyperkey
    chmod +x $out/bin/hyperkey
    runHook postInstall
  '';

  meta = with lib; {
    description = "Remaps Caps Lock to a Hyper key";
    license = licenses.mit;
    platforms = platforms.darwin;
  };

  __darwinAllowLocalNetworking = true;

  postInstall = ''
    echo "NOTE: HyperKey requires accessibility permissions."
    echo "      Please grant them in System Settings → Privacy & Security → Accessibility."
  '';
}
