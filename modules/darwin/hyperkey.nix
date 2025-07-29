{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.services.hyperkey;

  launchAgentConfig = {
    ProgramArguments = [
      "${pkgs.hyperkey}/bin/hyperkey"
    ]
    ++ (if !cfg.normalQuickPress then [ "--no-quick-press" ] else [ ])
    ++ (if cfg.includeShift then [ "--include-shift" ] else [ ]);
    RunAtLoad = true;
    KeepAlive = true;
    EnvironmentVariables = {
      PATH = "/run/current-system/sw/bin:/usr/bin:/bin:/usr/sbin:/sbin";
    };
    SessionCreate = true;
  };
in
{
  options.services.hyperkey = {
    enable = lib.mkEnableOption "HyperKey service that remaps Caps Lock to a Hyper key";

    normalQuickPress = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = ''
        If enabled, a quick press of the Caps Lock key will send an Escape key.
        If disabled, it will only act as the Hyper key.
      '';
    };

    includeShift = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = ''
        If enabled, the Hyper key will include the Shift modifier (Cmd+Ctrl+Opt+Shift).
        If disabled, it will only include Cmd+Ctrl+Opt.
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    environment.systemPackages = [ pkgs.hyperkey ];
    launchd.user.agents.hyperkey.serviceConfig = launchAgentConfig;
  };
}
