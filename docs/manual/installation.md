# Installation

Nixkit can be used as a flake input or imported directly.

## Flake Usage

Add to your flake inputs:

```nix
inputs.nixkit.url = "github:frostplexx/nixkit";
```

Then import the modules:

```nix
# For NixOS
imports = [ nixkit.nixosModules.default ];

# For nix-darwin
imports = [ nixkit.darwinModules.default ];

# For Home Manager
imports = [ nixkit.homeModules.default ];
```