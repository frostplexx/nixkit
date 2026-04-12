{
  description = "Support developing Nixkit documentation";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
  };

  outputs = {
    self,
    nixpkgs,
  }: let
    supportedSystems = [
      "aarch64-darwin"
      "aarch64-linux"
      "x86_64-darwin"
      "x86_64-linux"
    ];

    forAllSystems = nixpkgs.lib.genAttrs supportedSystems;

    releaseInfo =
      self.outputs.self or {
        release = "unstable";
      };
  in {
    devShells = forAllSystems (
      system: let
        pkgs = nixpkgs.legacyPackages.${system};
      in {
        default = pkgs.mkShell {
          name = "nixkit-docs";
        };
      }
    );

    packages = forAllSystems (
      system: let
        pkgs = nixpkgs.legacyPackages.${system};
        docs = import ./default.nix {
          inherit pkgs;
          lib = pkgs.lib;
        };
      in {
        inherit (docs) manPages;
        inherit (docs.options) json;
      }
    );
  };
}
