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
  marker = "/Library/Application Support/nixkit/mac-mouse-fix.source";
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
    # Mac Mouse Fix registers its Helper via SMAppService, which only works from
    # a stable, writable /Applications install — not a read-only /nix/store path
    # (and not /Applications/Nix Apps aliases). So copy a real, mutable bundle
    # into /Applications on activation. Idempotent via an out-of-bundle marker:
    # we only re-copy when the source store path changes, so the ad-hoc cdhash
    # (and thus the Accessibility/Input Monitoring grants) only churns on a real
    # update, not every rebuild.
    #
    # Do NOT also add the package to environment.systemPackages: a second copy
    # under /Applications/Nix Apps makes launchd/SMAppService register the wrong
    # Helper (see HelperServices.m notes upstream).
    system.activationScripts.extraActivation.text = mkAfter ''
      if [ "$(cat ${escapeShellArg marker} 2>/dev/null)" != "${cfg.package}" ]; then
        echo "nixkit: installing Mac Mouse Fix into /Applications..." >&2
        rm -rf ${escapeShellArg dest}
        /usr/bin/ditto ${escapeShellArg "${cfg.package}/Applications/${appName}"} ${escapeShellArg dest}
        chmod -R u+w ${escapeShellArg dest}
        mkdir -p ${escapeShellArg (dirOf marker)}
        printf '%s' ${escapeShellArg "${cfg.package}"} > ${escapeShellArg marker}
      fi
    '';
  };
}
