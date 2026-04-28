{
  lib,
  stdenv,
  pkgs,
  nix-update-script,
}: let
  version = "0.0.17";
in
  stdenv.mkDerivation {
    pname = "skhd_zig";
    inherit version;

    src = pkgs.fetchurl {
      url = "https://github.com/jackielii/skhd.zig/releases/download/v${version}/skhd-arm64-macos.tar.gz";
      hash = "sha256-1lvvQoUOCxpus07L5KsG1l30GI+LP+KkvLGQN12KFhs=";
    };

    sourceRoot = ".";

    installPhase = ''
      mkdir -p $out/bin
      cp skhd-arm64-macos $out/bin/skhd
      chmod +x $out/bin/skhd
    '';

    passthru.updateScript = nix-update-script {};

    meta = with lib; {
      description = "Simple Hotkey Daemon for macOS, ported from skhd by koekeishiya";
      homepage = "https://github.com/jackielii/skhd.zig";
      license = licenses.mit;
      mainProgram = "skhd";
      platforms = ["aarch64-darwin"];
    };
  }
