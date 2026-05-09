{
  lib,
  stdenv,
  pkgs,
  nix-update-script,
}: let
  version = "0.1.2";
in
  stdenv.mkDerivation {
    pname = "skhd_zig";
    inherit version;

    src = pkgs.fetchurl {
      url = "https://github.com/jackielii/skhd.zig/releases/download/v${version}/skhd-arm64-macos.tar.gz";
      hash = "sha256-mq1LzC9GKsr/YTYJRD0XbZBh8+N6q5Q2duTv02pgfjg=";
    };

    sourceRoot = ".";

    installPhase = ''
      mkdir -p $out/bin
      cp skhd.app/Contents/MacOS/skhd $out/bin/skhd
      chmod +x $out/bin/skhd
    '';

    passthru.updateScript = nix-update-script {extraArgs = ["--version-regex" "v([0-9]+\\.[0-9]+\\.[0-9]+)$"];};

    meta = with lib; {
      description = "Simple Hotkey Daemon for macOS, ported from skhd by koekeishiya";
      homepage = "https://github.com/jackielii/skhd.zig";
      license = licenses.mit;
      mainProgram = "skhd";
      platforms = ["aarch64-darwin"];
    };
  }
