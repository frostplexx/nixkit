{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.programs.ndcli;

  # Global version
  version = "5.0.4";

  # Build the dimclient dependency first
  dimclient = pkgs.python3Packages.buildPythonPackage {
    pname = "dimclient";
    inherit version;
    format = "pyproject";

    src = pkgs.fetchFromGitHub {
      owner = "ionos-cloud";
      repo = "dim";
      rev = "ndcli-${version}";
      sha256 = "sha256-s+4UgeJkqojtM73miE9hr7C8HduXJRHDIFfJxL2wZQ4=";
    };

    sourceRoot = "source/dimclient";

    nativeBuildInputs = with pkgs.python3Packages; [
      setuptools
      pip
      wheel
    ];

  };

  # Build the ndcli package
  ndcli = pkgs.python3Packages.buildPythonPackage {
    pname = "ndcli";
    inherit version;
    format = "pyproject";

    src = pkgs.fetchFromGitHub {
      owner = "ionos-cloud";
      repo = "dim";
      rev = "ndcli-${version}";
      sha256 = "sha256-s+4UgeJkqojtM73miE9hr7C8HduXJRHDIFfJxL2wZQ4=";
    };

    sourceRoot = "source/ndcli";

    nativeBuildInputs = with pkgs.python3Packages; [
      setuptools
      pip
      wheel
    ];

    propagatedBuildInputs = [
      dimclient
      pkgs.python3Packages.python-dateutil
      pkgs.python3Packages.dnspython
    ];

  };
in {
  options.programs.ndcli = {
    enable = mkEnableOption "ndcli command line tool";
    
    server = mkOption {
      type = types.str;
      default = "http://localhost:5000";
      description = "DIM server URL";
    };

    username = mkOption {
      type = types.str;
      default = config.home.username;
      description = "Username for DIM authentication";
    };
  };

  config = mkIf cfg.enable {
    home.packages = [ ndcli ];

    home.file.".ndclirc".text = ''
      server = ${cfg.server}
      username = ${cfg.username}
    '';
  };
}
