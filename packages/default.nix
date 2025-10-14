{
  pkgs ? import <nixpkgs> { },
}:

let
  # Define packages with proper dependency handling
  dimclient = pkgs.callPackage ./dimclient { };
  ndcli = pkgs.callPackage ./ndcli { inherit dimclient; };
in

{
  inherit dimclient ndcli;
  defaultbrowser = pkgs.callPackage ./defaultbrowser { };
  opsops = pkgs.callPackage ./opsops { };
  aerospace-swipe = pkgs.callPackage ./aerospace-swipe { };
}
