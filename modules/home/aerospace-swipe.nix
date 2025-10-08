{

    config,
    lib,
    pkgs,
    ...
}:

with lib;

let 
    cfg = config.programs.aerospace-swipe;

    configFile = pkgs.writeText "aerospace-swipe-config.json" (builtins.toJSON {
        inherit (cfg) haptic natural_swipe wrap_around skip_empty fingers;
    });
in
{
    options.programs.aerospace-swipe = {
        enable = mkEnableOption "aerospace-swipe configuration";

        haptic = mkOption {
            type = types.bool;
            default = false;
            example = "true";
            description = "Enable haptic feedback";
        };

        natural_swipe = mkOption {
            type = types.bool;
            default = false;
            example = "true";
            description = "Enable natural swipe";
        };

        wrap_around = mkOption {
            type = types.bool;
            default = true;
            example = "false";
            description = "Wrap around workpsace";
        };

        skip_empty = mkOption {
            type = types.bool;
            default = true;
            example = "false";
            description = "Skip empty workspaces";
        };

        fingers = mkOption {
            type = types.int;
            default = 3;
            example = "4";
            description = "Number of fingers needed for swipe";
        };
    };

    config = mkIf cfg.enable {
        home.packages = lib.optional pkgs.stdenv.isDarwin pkgs.aerospace-swipe;
        
        home.file.".config/aerospace-swipe/config.json".source = configFile;
    };


}
