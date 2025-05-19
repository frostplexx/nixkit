{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.programs.opsops;

  opsops = pkgs.rustPlatform.buildRustPackage rec {
    pname = "opsops";
    version = "1.1.0";

    src = pkgs.fetchFromGitHub {
      owner = "frostplexx";
      repo = "opsops";
      rev = "v${version}";
      sha256 = "sha256-0bnzSWIJ1yD7FhfFSGdrNsyZnMq7Dhu2dijuG5rG19g=";
    };

    cargoHash = "sha256-6IGoaxmQEIlPUU9w9Fa1CMDdhtIoVl9hRGaqqgvxPPQ=";

    nativeBuildInputs = with pkgs; [ pkg-config ];
    buildInputs = with pkgs; [ openssl ];

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
