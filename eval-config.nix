{
  lib,
  modules,
  baseModules ? [],
  specialArgs ? {},
} @ args: let
  argsModule = {
    _file = ./eval-config.nix;
    config = {
      _module.args = {
        inherit baseModules modules;
      };
    };
  };

  eval = lib.evalModules (builtins.removeAttrs args ["lib"]
    // {
      modules = modules ++ [argsModule] ++ baseModules;
    });
in
  eval
