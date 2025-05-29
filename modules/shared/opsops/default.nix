{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.programs.opsops;

  opsops = pkgs.rustPlatform.buildRustPackage rec {
    pname = "opsops";
    version = "1.3.0";

    src = pkgs.fetchFromGitHub {
      owner = "frostplexx";
      repo = "opsops";
      rev = "v${version}";
      sha256 = "sha256-t+sMHIRw2SaIkH2caMgPX0Zteb76oe0oryCtW0hO1kc=";
    };

    cargoHash = "sha256-7zTe2a9hKdaoAIUpifUYh1LPFBUTFMQBC3NYUnoK8/g=";

    nativeBuildInputs = with pkgs; [ pkg-config ];
    buildInputs = with pkgs; [ openssl sops ];

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
