{

  config,
  lib,
  pkgs,
  ...
}:

with lib;

let
  cfg = config.programs.nixupdater;
in
{
  options.programs.nixupdater = {
    enable = mkEnableOption "nixupdater configuration";

    interval = mkOption {
      type = types.int;
      default = 1800;
      example = "300";
      description = "Set the intervall in seconds for checking for updates";
    };

    flake = mkOption {
      type = types.str;
      default = "";
      example = "/Users/alice/other-dotfiles";
      description = "Sets the flake path.";
    };

    command = mkOption {
      type = types.str;
      default = "jinx update";
      example = "darwin-rebuild switch --flake .#my-mac";
      description = "Command to run when updates are available. Can be used to trigger a notification or directly apply updates";
    };

    terminal = mkOption {
      type = types.str;
      default = "kitty";
      example = "alacritty";
      description = "Terminal to use for running the command. Only used if command is set and not empty";
    };
  };

  config = mkIf cfg.enable {
    home.packages = lib.optional pkgs.stdenv.isDarwin pkgs.nixupdater;

    launchd.agents.nixupdater = {
      enable = true;
      config = {
        EnvironmentVariables = {
          PATH = builtins.concatStringsSep ":" [
            "/run/current-system/sw/bin"
            "/etc/profiles/per-user/${config.home.username}/bin"
            "/opt/homebrew/bin"
            "/usr/local/bin"
            "/usr/bin"
            "/bin"
            "/usr/sbin"
            "/sbin"
          ];
          # NH_FLAKE = cfg.flake;
        };
        ProgramArguments = [
          "${pkgs.nixupdater}/NixUpdater.app/Contents/MacOS/NixUpdater"
          "--interval"
          "${toString cfg.interval}"
          "--flake"
          "${cfg.flake}"
          "--command"
          "${cfg.command}"
          "--terminal"
          "${cfg.terminal}"
        ];
        RunAtLoad = true;
        KeepAlive = true;
        ProcessType = "Interactive";
        StandardOutPath = "/tmp/nixupdater.log";
        StandardErrorPath = "/tmp/nixupdater.log";
      };
    };
  };

}
