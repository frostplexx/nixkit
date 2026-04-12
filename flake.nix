{
  description = "Various internal modules and packages for NixOS and nix-darwin";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
  };

  outputs = {
    self,
    nixpkgs,
  }: let
    systems = [
      "x86_64-linux"
      "aarch64-linux"
      "x86_64-darwin"
      "aarch64-darwin"
    ];
    forAllSystems = nixpkgs.lib.genAttrs systems;
  in {
    packages = forAllSystems (
      system: let
        pkgs = nixpkgs.legacyPackages.${system};
        allPkgs = import ./packages {inherit pkgs;};
        docPkgs = import ./docs/default.nix {
          inherit pkgs;
          lib = pkgs.lib;
        };
        pkgSet =
          pkgs.lib.filterAttrs (
            _: p:
              pkgs.lib.isDerivation p
              && pkgs.lib.meta.availableOn pkgs.stdenv.hostPlatform p
              && !(p.meta.unsupported or false)
          )
          allPkgs;
      in
        pkgSet
        // {
          nixkit-docs-json = docPkgs.options.json;
          nixkit-docs-html = docPkgs.html;
          nixkit-docs-man = docPkgs.manPages;
        }
    );

    # Overlay for easy integration
    overlays.default = import ./overlay.nix;

    # Module outputs
    homeModules.default = import ./modules/home;

    nixosModules.default = {
      nixpkgs.overlays = [self.overlays.default];
      imports = [./modules/nixos];
    };

    darwinModules.default = {
      nixpkgs.overlays = [self.overlays.default];
      imports = [./modules/darwin];
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
