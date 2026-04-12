{
  lib,
  pkgs,
}:
lib.evalModules {
  modules = [
    ./modules/nixos
    ./modules/darwin
    ./modules/home
  ];
}
