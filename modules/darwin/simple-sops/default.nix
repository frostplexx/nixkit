{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.programs.simple-sops;

  simple-sops = pkgs.buildGoModule rec {
    pname = "simple-sops";
    version = "1.0.0";

    src = pkgs.fetchFromGitHub {
      owner = "ojsef39";
      repo = "simple-sops";
      rev = "v${version}";
      sha256 = "sha256-75im/QPcGUUMTzv7NzLxXkJ+Qn0aoZCjkDlYawMVMkU=";
    };

    vendorHash = "sha256-sZUEzBxbButVYi8eFxyrqCQI51a8rUDXpvO1JUxSmjU=";

    meta = with lib; {
      description = "A simple tool for managing secrets (with 1password integration)";
      homepage = "https://github.com/ojsef39/simple-sops";
      license = licenses.mit;
      maintainers = with maintainers; [ ojsef39 ];
      mainProgram = "simple-sops";
    };
  };
in {
  options.programs.simple-sops = {
    enable = mkEnableOption "simple-sops tool";
  };

  config = mkIf cfg.enable {
    environment.systemPackages = [ simple-sops ];
  };
}
