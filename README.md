# nixkit

A collection of various nix utilities packaged as Nix flakes with configurable
modules for NixOS, nix-darwin, and Home Manager.

**[View Documentation](https://frostplexx.github.io/nixkit/)**

## 🚀 Installation

Add it to your `flake.nix` inputs:

```nix
nixkit = {
    url = "github:frostplexx/nixkit";
    # or for local development:
    # url = "path:/path/to/nixkit";
};
```

Add the home manager module:

```nix
home-manager = {
    sharedModules = [
        inputs.nixkit.homeModules.default
    ];
};
```

Add the nix module:

**On NixOS:**

```nix
modules = [
    inputs.nixkit.nixosModules.default
];
```

**On macOS:**

```nix
modules = [
    inputs.nixkit.darwinModules.default
];
```

### Using the Overlay

```nix
{
  nixpkgs.overlays = [ nixkit.overlays.default ];

  # Now packages are available as pkgs.opsops, pkgs.ndcli, etc.
  environment.systemPackages = with pkgs; [
    opsops
    ndcli
  ];
}
```

### Direct Package Installation

```bash
# Install individual packages
nix profile install github:frostplexx/nixkit#opsops
nix profile install github:frostplexx/nixkit#ndcli

# Or run directly
nix run github:frostplexx/nixkit#opsops
```

## 🤖 Automated Updates

The repository includes automated package updates via GitHub Actions:

- **Schedule**: Daily at 6 AM Berlin time
- **Process**: Creates individual PRs for each package update
- **Safety**: Builds and tests packages before creating PRs
- **Manual trigger**: Available via GitHub Actions interface

## 🤝 Contributing

1. Add new packages to `packages/`
2. Create corresponding modules in `modules/home/`, `modules/shared/`, or
   platform-specific directories
3. Update `packages/default.nix` and `flake.nix`
4. Test with `nix build .#package-name`
5. Verify `nix-update package-name` works for automated updates
