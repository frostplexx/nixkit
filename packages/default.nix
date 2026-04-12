{
  pkgs ? import <nixpkgs> {},
  system ? builtins.currentSystem,
}: let
  isLinux = system == "x86_64-linux" || system == "aarch64-linux";
  isDarwin = system == "x86_64-darwin" || system == "aarch64-darwin";

  dimclient = pkgs.callPackage ./dimclient {};
  ndcli = pkgs.callPackage ./ndcli {inherit dimclient;};

  packages =
    {
    }
    // (
      if isDarwin
      then {
        defaultbrowser = pkgs.callPackage ./defaultbrowser {};
        nixupdater = pkgs.callPackage ./nixupdater {};
        opsops = pkgs.callPackage ./opsops {};
        aerospace-swipe = pkgs.callPackage ./aerospace-swipe {};
        skhd_zig = pkgs.callPackage ./skhd_zig {};
      }
      else {}
    )
    // (
      if isLinux
      then {
        sunshine-virt-display = pkgs.callPackage ./sunshine-virt-display {};
      }
      else {}
    );
in
  packages // {inherit dimclient ndcli;}
