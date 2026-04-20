{
  pkgs ? import <nixpkgs> {},
  system ? builtins.currentSystem,
}: let
  isLinux = system == "x86_64-linux" || system == "aarch64-linux";
  isDarwin = system == "x86_64-darwin" || system == "aarch64-darwin";

  # Override nix-update-script to always include --flake so individual packages
  # don't need to specify it manually.
  pkgs' = pkgs.extend (_: prev: {
    nix-update-script = {extraArgs ? []}: prev.nix-update-script {extraArgs = ["--flake"] ++ extraArgs;};
  });

  dimclient = pkgs'.callPackage ./dimclient {};
  ndcli = pkgs'.callPackage ./ndcli {inherit dimclient;};
  prlspPkgs = pkgs'.callPackage ./prlsp {};
  inherit (prlspPkgs) prlsp prlsp-nvim;

  packages =
    {
      prometheus-mcp-server = pkgs'.callPackage ./prometheus-mcp-server {};
      kubernetes-mcp-server = pkgs'.callPackage ./kubernetes-mcp-server {};
    }
    // (
      if isDarwin
      then {
        defaultbrowser = pkgs'.callPackage ./defaultbrowser {};
        nixupdater = pkgs'.callPackage ./nixupdater {};
        opsops = pkgs'.callPackage ./opsops {};
        aerospace-swipe = pkgs'.callPackage ./aerospace-swipe {};
        skhd_zig = pkgs'.callPackage ./skhd_zig {};
      }
      else {}
    )
    // (
      if isLinux
      then {
        sunshine-virt-display = pkgs'.callPackage ./sunshine-virt-display {};
        opsops = pkgs'.callPackage ./opsops {};
      }
      else {}
    );
in
  packages // {inherit dimclient ndcli prlsp prlsp-nvim;}
