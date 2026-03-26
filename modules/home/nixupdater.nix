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
      description = "Set the interval in seconds for checking for updates";
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
      type = types.enum [
        "terminal"
        "iterm"
        "kitty"
        "kitty-tab"
        "kitty-overlay"
        "alacritty"
        "ghostty"
      ];
      default = "kitty";
      example = "kitty-overlay";
      description = ''
        Terminal to use for running the update command. Options:
          terminal        macOS Terminal.app
          iterm           iTerm2
          kitty           new kitty window (default)
          kitty-tab       new tab in the running kitty instance *
          kitty-overlay   overlay in the focused kitty window *
          alacritty
          ghostty

        * kitty-tab and kitty-overlay use kitty's remote-control protocol
          (kitty @ new-window). They require `allow_remote_control yes` in
          kitty.conf, or kitty launched with --listen-on / KITTY_LISTEN_ON.
          Falls back to a new kitty window when no running instance is found.
      '';
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
            "/nix/var/nix/profiles/default/bin"
            "/usr/local/bin"
            "/usr/bin"
            "/bin"
            "/usr/sbin"
            "/sbin"
          ];
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
