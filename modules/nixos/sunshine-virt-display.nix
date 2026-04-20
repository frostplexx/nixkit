{
  config,
  lib,
  pkgs,
  ...
}:
with lib; let
  cfg = config.services.sunshine-virt-display;
in {
  options.services.sunshine-virt-display = {
    enable = mkEnableOption "sunshine-virt-display virtual display integration";

    user = mkOption {
      type = types.str;
      description = "Username to grant passwordless sudo for the virtual display script";
    };

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

    services.sunshine.applications.apps = [
      (
        {
          name = "Virtual Desktop";
          prep-cmd = [
            {
              do = ''sh -c "${pkgs.sunshine-virt-display}/bin/virt_display.sh --connect --width ''${SUNSHINE_CLIENT_WIDTH} --height ''${SUNSHINE_CLIENT_HEIGHT} --refresh-rate ''${SUNSHINE_CLIENT_FPS}"'';
              undo = "${pkgs.sunshine-virt-display}/bin/virt_display.sh --disconnect";
            }
          ];
        }
        // optionalAttrs (cfg.virtual-desktop-icon != null) {
          image-path = cfg.virtual-desktop-icon;
        }
      )
    ];

    security.sudo.extraRules = [
      {
        users = [cfg.user];
        commands = [
          {
            command = "${pkgs.python3}/bin/python3 ${pkgs.sunshine-virt-display}/share/sunshine-virt-display/main.py *";
            options = ["NOPASSWD"];
          }
        ];
      }
    ];

    boot.kernelModules = ["debugfs"];
  };
}
