{
  config,
  lib,
  pkgs,
  ...
}:

with lib;

let
  cfg = config.programs.default-browser;
in
{
  options.programs.default-browser = {
    enable = mkEnableOption "Default browser configuration";

    browser = mkOption {
      type = types.str;
      default = "";
      example = "firefox";
      description = "The browser to set as default";
    };
  };

  config = mkIf cfg.enable {
    home.packages = [
      # Include the xdg-utils for Linux systems
      pkgs.xdg-utils
    ]
    ++ lib.optional pkgs.stdenv.isDarwin pkgs.defaultbrowser;

    home.activation.setDefaultBrowser = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
      setDefaultBrowser() {
        local browser="$1"
        local isLinux

        # Check if system is Linux
        case "$(uname -s)" in
          Linux*)  isLinux=1 ;;
          *)       isLinux=0 ;;
        esac

        if [ "$isLinux" -eq 1 ]; then
          # Linux-specific method using xdg-settings
          echo "Setting default browser on Linux to $browser"
          ${pkgs.xdg-utils}/bin/xdg-settings set default-web-browser "$browser.desktop"
        else
          # macOS systems use the compiled utility
          echo "Setting default browser to $browser"
          $DRY_RUN_CMD ${
            if pkgs.stdenv.isDarwin then "${pkgs.defaultbrowser}/bin/defaultbrowser" else "defaultbrowser"
          } "$browser"
        fi
      }

      setDefaultBrowser "${cfg.browser}"
    '';
  };
}
