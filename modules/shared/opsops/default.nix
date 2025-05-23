{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.programs.opsops;

  opsops = pkgs.rustPlatform.buildRustPackage rec {
    pname = "opsops";
    version = "1.2.0";

    src = pkgs.fetchFromGitHub {
      owner = "frostplexx";
      repo = "opsops";
      rev = "v${version}";
      sha256 = "sha256-iBRK6zatU5WwBDF42TWiy0rYAIVM5mBDbSBsre9ezIs=";
    };

    cargoHash = "sha256-fOpDooUmsdkoy4E23CCq13Buicl6q4wX7qphbRSble8=";

    nativeBuildInputs = with pkgs; [ pkg-config ];
    buildInputs = with pkgs; [ openssl ];

    postInstall = ''
      # Create directories for docs
      mkdir -p $out/share/man/man1
      mkdir -p $out/share/fish/vendor_completions.d
      
      # Generate docs
      $out/bin/opsops generate-docs --dir $TMPDIR/docs
      
      # Install man page
      cp $TMPDIR/docs/man/opsops.1 $out/share/man/man1/
      
      # Install fish completions
      cp $TMPDIR/docs/completions/opsops.fish $out/share/fish/vendor_completions.d/
    '';

    meta = with lib; {
      description = "A simple tool for managing secrets (with 1password integration)";
      homepage = "https://github.com/frostplexx/opsops";
      license = licenses.mit;
      maintainers = with maintainers; [ frostplexx ojsef39 ];
      mainProgram = "opsops";
    };
  };
in {
  options.programs.opsops = {
    enable = mkEnableOption "opsops";
  };

  config = mkIf cfg.enable {
    environment.systemPackages = [ opsops ];
  };
}
