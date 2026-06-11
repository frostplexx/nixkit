{
  config,
  lib,
  pkgs,
  ...
}:
with lib; let
  cfg = config.programs.mac-mouse-fix;
  appName = "Mac Mouse Fix.app";
  dest = "/Applications/${appName}";
in {
  options.programs.mac-mouse-fix = {
    enable = mkEnableOption "Mac Mouse Fix, installed into /Applications";

    package = mkOption {
      type = types.package;
      default = pkgs.mac-mouse-fix;
      defaultText = literalExpression "pkgs.mac-mouse-fix";
      description = "The mac-mouse-fix package to install.";
    };
  };

  config = mkIf cfg.enable {
    # Copy into /Applications; SMAppService won't enable from a store path.
    home.activation.macMouseFix = lib.hm.dag.entryAfter ["writeBoundary"] ''
      [ -e ${escapeShellArg dest} ] && $DRY_RUN_CMD chmod -R u+w ${escapeShellArg dest}
      $DRY_RUN_CMD rm -rf ${escapeShellArg dest}
      $DRY_RUN_CMD /usr/bin/ditto ${escapeShellArg "${cfg.package}/Applications/${appName}"} ${escapeShellArg dest}
      $DRY_RUN_CMD chmod -R u+w ${escapeShellArg dest}
    '';
  };
}
