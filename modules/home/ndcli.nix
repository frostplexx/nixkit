{
  config,
  lib,
  pkgs,
  ...
}:

with lib;

let
  cfg = config.programs.ndcli;
in
{
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
    home.packages = [ pkgs.ndcli ];

    home.file.".ndclirc".text = ''
      server = ${cfg.server}
      username = ${cfg.username}
    '';
  };
}
