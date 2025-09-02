# nixkit

A collection of various nix utilities packaged as Nix flakes with configurable modules for NixOS, nix-darwin, and Home Manager.

## 📦 Packages

| Package            | Description                                            | Type           |
| ------------------ | ------------------------------------------------------ | -------------- |
| **opsops**         | SOPS but easy with 1Password integration               | Rust binary    |
| **ndcli**          | Command line interface for DIM (DNS and IP Management) | Python CLI     |
| **dimclient**      | Python client for DIM (dependency of ndcli)            | Python package |
| **defaultbrowser** | Utility to set the default browser on macOS            | C binary       |

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

## 🔧 Module Configuration

### Home Manager Modules

#### Set Default Browser

To set the default browser on macOS and Linux use the following:

```nix
# Enable and configure the default browser
programs.default-browser = {
    enable = true;
    browser = "firefox"; # Or any other browser name
};
```

#### ndcli - cli tool for Dim

```nix
{
  programs.ndcli = {
    enable = true;
    username = "johndoe"; # Your Dim username
  };
}
```

Source: <https://github.com/ionos-cloud/dim/tree/master/ndcli>

### System Modules

#### Darwin

##### Custom Icons

You can configure custom icons on macOS using the following snippet:

```nix
 environment.customIcons = {
    enable = true;
    icons = [
      {
        path = "/Applications/Notion.app";
        icon = ./icons/notion.icns;
      }
    ];
  };
```

Source: <https://github.com/ryanccn/nix-darwin-custom-icons>

#### Shared

##### opsops

SOPS but easy and with 1Password integration:

```nix
  programs = {
    opsops.enable = true;
  };
```

Source: <https://github.com/frostplexx/opsops>

## 🔧 Development

### Development Environment

Enter the development shell with all necessary tools:

```bash
direnv allow
```

### Building Packages

```bash
# Build individual packages
nix build .#opsops

# Test the built packages
./result/bin/opsops --help
```

### Updating Packages

This repository uses [nix-update](https://github.com/Mic92/nix-update) for automated package updates:

```bash
# Update individual packages
nix-update opsops --build --commit (--version 1.2.3)
nix-update ndcli --build --commit

# Update all packages
./scripts/update.sh
```

**Automated Updates:**

- GitHub Actions runs daily at 6 AM Berlin time
- Creates individual PRs for each package update
- Automatically builds and tests packages before creating PRs

### Repository Structure

```
nixkit/
├── packages/                    # Package definitions (nix-update compatible)
│   ├── default.nix             # Package set entry point
│   ├── opsops/
│   ├── ndcli/
│   ├── dimclient/
│   └── defaultbrowser/
│
├── modules/
│   ├── home/                    # Home Manager modules
│   │   ├── default-browser.nix
│   │   ├── ndcli.nix
│   │   └── default.nix
│   ├── shared/                  # Shared NixOS/Darwin modules
│   │   ├── opsops.nix
│   │   └── default.nix
│   ├── nixos/                   # NixOS-specific modules
│   │   └── default.nix
│   └── darwin/                  # Darwin-specific modules
│       └── default.nix
├── flake.nix                    # Flake definition
├── overlay.nix                  # Package overlay
├── default.nix                  # Legacy Nix compatibility
└── update.sh                    # Package update script
```

## 📋 Requirements

- Nix with flakes enabled
- For Home Manager modules: [Home Manager](https://github.com/nix-community/home-manager)
- For NixOS modules: NixOS system
- For Darwin modules: [nix-darwin](https://github.com/LnL7/nix-darwin)

## 🤖 Automated Updates

The repository includes automated package updates via GitHub Actions:

- **Schedule**: Daily at 6 AM Berlin time
- **Process**: Creates individual PRs for each package update
- **Safety**: Builds and tests packages before creating PRs
- **Manual trigger**: Available via GitHub Actions interface

## 📝 License

Personal use repository.

## 🤝 Contributing

1. Add new packages to `packages/`
2. Create corresponding modules in `modules/home/`, `modules/shared/`, or platform-specific directories
3. Update `packages/default.nix` and `flake.nix`
4. Test with `nix build .#package-name`
5. Verify `nix-update package-name` works for automated updates
