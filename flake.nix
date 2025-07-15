{
    description = "Various modules and utilities for NixOS and nix-darwin";

    inputs = {
        nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    };

    outputs = { ... }: {

        nixosModules.default  = {
            imports = [./modules/shared ./modules/nixos];
        };

        darwinModules.default  = {
            imports = [./modules/shared ./modules/darwin];
        };

        homeModules.default = {
            imports = [./home];
        };
    };
}
