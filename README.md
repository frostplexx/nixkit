# A Collection of various nix utilities


# Installation


Add it to your `flake.nix` inputs:
```nix
nix-utils = {
    url = "github:frostplexx/nixkit";
    # or for local development:
    # url = "path:/Users/daniel/Developer/nix-utils";
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
```nix
modules = [
    inputs.nixkit.nixosModules.default
];
```


# Home Manager Modules

## Set Default Browser

To set the default browser on macOS and Linux use the following:
```nix
# Enable and configure the default browser
programs.default-browser = {
    enable = true;
    browser = "firefox"; # Or any other browser name
};
```


# System Modules

## Darwin

### Hyperkey

`hyperkey` is a simple service that maps caps-lock to cmd+opt+ctrl or optionally cmd+opt+ctrl+shift.
Simply enable it using the following snippet inside your `configuration.nix`:
```nix
services.hyperkey = {
    enable = true;
    normalQuickPress = true; # Quick press of Caps Lock to toggle it
    includeShift = false; # Hyper key will be Cmd+Ctrl+Opt (without Shift)
};
```
On first start it will ask for accessibility permission. Afterward you may need to restart the service by running `killall hyperkey` for the permissions to
take effect.

### Custom Icons

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
Source: https://github.com/ryanccn/nix-darwin-custom-icons

## NixOS

## Shared


### Declare Folders

SOON

### Auto Fetch Flake and Update

SOON
