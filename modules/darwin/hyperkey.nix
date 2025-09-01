{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.services.hyperkey;
in
{
  options.services.hyperkey = {
    enable = lib.mkEnableOption "HyperKey service that remaps Caps Lock to a Hyper key" // {
      description = lib.mkDoc ''
        ⚠️  **DEPRECATED**: This package is deprecated. 
        Please use [lazykeys](https://github.com/frostplexx/lazykeys) instead for a more modern and feature-rich key mapping solution.
        
        HyperKey service that remaps Caps Lock to a Hyper key.
      '';
    };

# Legacy options kept for backwards compatibility but no longer functional
    normalQuickPress = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "DEPRECATED: This option no longer has any effect. Please migrate to lazykeys.";
    };

    includeShift = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "DEPRECATED: This option no longer has any effect. Please migrate to lazykeys.";
    };
  };

  config = lib.mkIf cfg.enable {
    warnings = [
      ''
        services.hyperkey is DEPRECATED and will be removed in a future release.
        Please migrate to lazykeys: https://github.com/frostplexx/lazykeys
        
        The hyperkey service will no longer function and only displays deprecation warnings.
      ''
    ];
    
    environment.systemPackages = [ pkgs.hyperkey ];
  };
}
