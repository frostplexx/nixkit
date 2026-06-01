{
  pkgs ? import <nixpkgs> {},
  system ? builtins.currentSystem,
}: let
  isLinux = system == "x86_64-linux" || system == "aarch64-linux";
  isDarwin = system == "x86_64-darwin" || system == "aarch64-darwin";

  dimclient = pkgs.callPackage ./dimclient {};
  ndcli = pkgs.callPackage ./ndcli {inherit dimclient;};
  prlspPkgs = pkgs.callPackage ./prlsp {};
  inherit (prlspPkgs) prlsp prlsp-nvim;

  packages =
    {
      prometheus-mcp-server = pkgs.callPackage ./prometheus-mcp-server {};
      kubernetes-mcp-server = pkgs.callPackage ./kubernetes-mcp-server {};
    }
    // (
      if isDarwin
      then
        {
          defaultbrowser = pkgs.callPackage ./defaultbrowser {};
          nixupdater = pkgs.callPackage ./nixupdater {};
          opsops = pkgs.callPackage ./opsops {};
          aerospace-swipe = pkgs.callPackage ./aerospace-swipe {};
          skhd_zig = pkgs.callPackage ./skhd_zig {};
          yabai = pkgs.callPackage ./yabai {};
          raycast-beta = pkgs.callPackage ./raycast-beta {};
          podman-mac-helper = pkgs.callPackage ./podman-mac-helper {};
        }
        # zen-browser builds Firefox-with-zen from source. Requires Rust 1.90
        # exactly, so it depends on `pkgs.rust-bin` from rust-overlay. The flake's
        # perSystem extends pkgs with rust-overlay, so it's present there. The bare
        # `overlay.nix` does not extend — guard so importers without rust-overlay
        # just get zen-browser absent (not an eval error).
        // (
          if pkgs ? rust-bin
          then {zen-browser = pkgs.callPackage ./zen-browser {};}
          else {}
        )
      else {}
    )
    // (
      if isLinux
      then {
        sunshine-virt-display = pkgs.callPackage ./sunshine-virt-display {};
        opsops = pkgs.callPackage ./opsops {};
      }
      else {}
    );
in
  packages // {inherit dimclient ndcli prlsp prlsp-nvim;}
