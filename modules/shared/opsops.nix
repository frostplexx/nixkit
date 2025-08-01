{
  config,
  lib,
  pkgs,
  ...
}:

with lib;

let
  cfg = config.programs.opsops;
in
{
  options.programs.opsops = {
    enable = mkEnableOption "opsops";
  };

  config = mkIf cfg.enable {
    environment.systemPackages = [ pkgs.opsops ];
  };
}
