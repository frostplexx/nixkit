{
  config,
  lib,
  pkgs,
  ...
}:
with lib; let
  cfg = config.services.sunshine-virt-display;
  socket = "/tmp/sunshineVD.sock";
  nc = "${pkgs.netcat-openbsd}/bin/nc";
in {
  imports = [
    (mkRemovedOptionModule
      ["services" "sunshine-virt-display" "user"]
      "sunshine-virt-display v2 runs as a root systemd daemon and no longer needs a per-user sudo rule. Remove `services.sunshine-virt-display.user` from your configuration.")
  ];

  options.services.sunshine-virt-display = {
    enable = mkEnableOption "sunshine-virt-display virtual display integration";

    virtual-desktop-icon = mkOption {
      type = types.nullOr types.path;
      default = pkgs.fetchurl {
        url = "https://raw.githubusercontent.com/ClassicOldSong/Apollo/25eb5c87149243e7f40cd564a7d2918160a94e64/src_assets/common/assets/virtual_desktop.png";
        hash = "sha256-jrz4NjRTZzujCVl5gL2+2syFNHN21YDPkMMgpH8ak5g=";
      };
      description = "Path to the Virtual Desktop app icon. Defaults to Apollo's virtual_desktop.png. Set to null to omit.";
    };
  };

  config = mkIf cfg.enable {
    assertions = [
      {
        assertion = config.services.sunshine.enable;
        message = "services.sunshine-virt-display.enable requires services.sunshine.enable = true";
      }
    ];

    systemd.services.sunshineVD = {
      description = "Sunshine Virtual Display Daemon";
      wantedBy = ["multi-user.target"];
      after = ["display-manager.service" "dbus.service"];
      requires = ["dbus.service"];
      serviceConfig = {
        Type = "simple";
        ExecStart = "${pkgs.sunshine-virt-display}/bin/sunshineVD";
        Restart = "always";
        RestartSec = 3;
        TimeoutStopSec = 10;
        StateDirectory = "sunshine-virt-display";
      };
    };

    services.sunshine.applications.apps = [
      (
        {
          name = "Virtual Desktop";
          prep-cmd = [
            {
              do = ''sh -c "echo --connect,--width,''${SUNSHINE_CLIENT_WIDTH},--height,''${SUNSHINE_CLIENT_HEIGHT},--refresh-rate,''${SUNSHINE_CLIENT_FPS} | ${nc} -U ${socket}"'';
              undo = ''sh -c "echo --disconnect | ${nc} -U ${socket}"'';
            }
          ];
        }
        // optionalAttrs (cfg.virtual-desktop-icon != null) {
          image-path = cfg.virtual-desktop-icon;
        }
      )
    ];

    boot.kernelModules = ["debugfs"];
  };
}
