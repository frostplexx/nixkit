{
  description = "Various internal modules and packages for NixOS and nix-darwin";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
  };

  outputs =
    { self, nixpkgs }:
    let
      systems = [
        "x86_64-linux"
        "aarch64-linux"
        "x86_64-darwin"
        "aarch64-darwin"
      ];
      forAllSystems = nixpkgs.lib.genAttrs systems;
    in
    {
      packages = forAllSystems (
        system:
        let
          pkgsWithOverlay = import nixpkgs {
            inherit system;
            overlays = [ self.overlays.default ];
          };
        in
        {
          inherit (pkgsWithOverlay)
            defaultbrowser
            dimclient
            ndcli
            opsops
            ;
        }
      );

      # Overlay for easy integration
      overlays.default = import ./overlay.nix;

      # Legacy packages support (for nix-update compatibility)
      legacyPackages = forAllSystems (
        system: import ./packages { pkgs = nixpkgs.legacyPackages.${system}; }
      );

      # Module outputs
      homeModules.default = import ./modules/home;

      nixosModules.default = {
        nixpkgs.overlays = [ self.overlays.default ];
        imports = [ ./modules/nixos ];
      };

      darwinModules.default = {
        nixpkgs.overlays = [ self.overlays.default ];
        imports = [ ./modules/darwin ];
      };

      devShells = forAllSystems (system: {
        default = nixpkgs.legacyPackages.${system}.mkShell {
          packages = with nixpkgs.legacyPackages.${system}; [
            nix-update
            git
            python3
          ];

          shellHook = ''
            echo "=> nixkit development environment ready!"
            echo "Available commands:"
            echo "  ./scripts/update.py                                                               # Update all packages (auto PR in CI)"
            echo ""
            echo "Manual updates:"
            echo "  nix-update <package> --flake --build --commit                                     # Update versioned package"
            echo "  nix-update <package> --flake --build --commit --version=branch --url <github-url> # Update unstable/branch package"
          '';
        };
      });
    };
}
