# Raycast Configuration Module

A Home Manager module for declarative Raycast configuration management using Nix. This module generates native `.rayconfig` files that can be imported directly into Raycast, enabling reproducible configuration across machines.

## Overview

This module provides three approaches to managing Raycast configuration:

1. **Declarative Configuration** - Define settings directly in Nix using structured options
2. **File Import** - Import existing `.rayconfig` exports as JSON files
3. **Attribute Set** - Use Nix attribute sets for full configuration control

The module handles encryption, compression, and format conversion automatically, producing `.rayconfig` files compatible with Raycast's native import functionality.

## Features

- Installs Raycast Beta (0.61.0.0) when module is enabled
- Declarative configuration of Raycast preferences, snippets, and extensions
- Import and export existing Raycast configurations
- Automatic `.rayconfig` file generation with proper encryption
- Scrypt + AES-256-GCM encryption support
- Helper utilities for config inspection and conversion
- Automated import via AppleScript (macOS only)
- No external dependencies beyond standard Nix tools

## Installation

Add the nixkit flake to your Home Manager configuration and import the Raycast module:

```nix
{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    nixkit.url = "github:frostplexx/nixkit";
  };

  outputs = { nixpkgs, nixkit, ... }: {
    homeConfigurations.username = home-manager.lib.homeManagerConfiguration {
      modules = [
        nixkit.homeManagerModules.default
        ./home.nix
      ];
    };
  };
}
```

## Quick Start

### Basic Configuration

Enable the module and define basic preferences. The module will automatically install Raycast Beta (0.61.0.0) to `/Applications/Raycast Beta.app`:

```nix
programs.raycast = {
  enable = true;

  preferences = {
    general.globalHotkey = "Option-49";
    appearance = {
      textSize = "medium";
      statusBarVisible = true;
    };
  };

  snippets = [
    {
      name = "Email Signature";
      text = "user@example.com";
      keyword = "email";
    }
  ];
};
```

**Note:** Raycast is unfree software. Ensure your NixOS configuration allows unfree packages:

```nix
nixpkgs.config.allowUnfree = true;
```

### Apply and Import

After running `home-manager switch`, import the generated configuration:

```bash
# Automated import (requires Accessibility permissions)
raycast-import-config

# Manual import
# 1. Open Raycast
# 2. Navigate to Settings → Advanced → Import Settings & Data
# 3. Select ~/.config/raycast/import.rayconfig
```

## Configuration Methods

### Method 1: Declarative Configuration

Define Raycast settings directly in Nix using structured options. This approach provides type safety and validation.

```nix
programs.raycast = {
  enable = true;
  version = "1.79.1";

  preferences = {
    general = {
      globalHotkey = "Command-49";
      alternativeEscape = false;
    };

    appearance = {
      statusBarVisible = true;
      textSize = "medium";        # Options: "small" | "medium" | "large"
      windowMode = "default";     # Options: "default" | "compact"
      showFavoritesInCompactMode = true;
    };

    advanced = {
      navigationStyle = "macos";
      popToRootTimeout = 90;
      keepWindowVisibleOnResign = false;
    };
  };

  snippets = [
    {
      name = "Shrug";
      text = "¯\\_(ツ)_/¯";
      keyword = "shrug";
    }
  ];

  fallbackSearches = [
    "builtin_command_fileSearch_fallbackSearch"
    "builtin_command_searchEmoji_fallbackSearch"
  ];

  encryptionPassword = "your-password";  # Optional
};
```

### Method 2: Import from JSON File

Import an existing Raycast export. This is the recommended approach for migrating existing configurations.

```nix
programs.raycast = {
  enable = true;
  configFile = ./raycast-config.json;
  
  # Re-encrypt with a different password (optional)
  encryptionPassword = "new-password";
};
```

### Method 3: Attribute Set Import

Use Nix expressions to load and manipulate configuration programmatically.

```nix
programs.raycast = {
  enable = true;
  settings = builtins.fromJSON (builtins.readFile ./raycast-export.json);
  encryptionPassword = "password";
};
```

### Advanced Configuration

Extend the configuration with custom package settings:

```nix
programs.raycast = {
  enable = true;
  preferences.general.globalHotkey = "Option-49";
  
  extraConfig = {
    builtin_package_github = {
      provider_schemaVersion = 1;
      repositories = ["owner/repo1" "owner/repo2"];
    };
    builtin_package_linear = {
      provider_schemaVersion = 1;
      teamIds = ["team-id-1"];
    };
  };
};
```

## Command-Line Utilities

The module provides several command-line utilities for working with `.rayconfig` files. The decrypt and encrypt utilities are always available, even when the module is disabled.

### raycast-decrypt-config

Decrypt and inspect `.rayconfig` files.

**Syntax:**
```bash
raycast-decrypt-config <input.rayconfig> [password] [output.json]
```

**Examples:**
```bash
# Decrypt with default password
raycast-decrypt-config export.rayconfig

# Decrypt with custom password
raycast-decrypt-config export.rayconfig mysecret output.json

# Process unencrypted file
raycast-decrypt-config export.rayconfig "" output.json
```

The decrypted JSON can be used with `configFile` or modified and re-imported.

### raycast-encrypt-config

Create `.rayconfig` files from JSON configuration.

**Syntax:**
```bash
raycast-encrypt-config <input.json> [password] [output.rayconfig]
```

**Examples:**
```bash
# Create unencrypted .rayconfig
raycast-encrypt-config config.json

# Create encrypted .rayconfig
raycast-encrypt-config config.json your-password

# Specify custom output path
raycast-encrypt-config config.json password output.rayconfig
```

### raycast-import-config

Automate the Raycast import process using AppleScript. Available only when the module is enabled.

**Syntax:**
```bash
raycast-import-config
```

This utility:
1. Activates Raycast
2. Invokes the configured global hotkey
3. Searches for "Import Settings & Data"
4. Attempts to automatically select the configuration file

**Requirements:**
- macOS Accessibility permissions for your terminal emulator
- Correct `automationHotkey` configuration

**Configuration:**
```nix
programs.raycast = {
  automationHotkey = "option down";  # Must match Raycast global hotkey
};
```

**Hotkey Values:**
- `"option down"` - Option+Space (default)
- `"command down"` - Cmd+Space
- `"control down"` - Ctrl+Space

## Exporting Existing Configuration

To migrate your current Raycast configuration to this module:

### Step 1: Export from Raycast

1. Open Raycast
2. Search for "Export Settings & Data"
3. Choose whether to encrypt (optional, recommended for sensitive data)
4. Save the `.rayconfig` file

### Step 2: Decrypt the Export

Convert the `.rayconfig` file to JSON:

```bash
raycast-decrypt-config ~/Downloads/Raycast-2026-05-27.rayconfig [password]
```

This produces `Raycast-2026-05-27.json` containing the configuration data.

### Step 3: Import to Nix

Reference the decrypted JSON in your configuration:

```nix
programs.raycast = {
  enable = true;
  configFile = ./Raycast-2026-05-27.json;
  
  # Optionally re-encrypt with a new password
  encryptionPassword = "new-password";
};
```

Alternatively, use an attribute set for programmatic manipulation:

```nix
programs.raycast = {
  enable = true;
  settings = builtins.fromJSON (builtins.readFile ./Raycast-2026-05-27.json);
};
```

## Module Options Reference

### Core Options

#### `programs.raycast.enable`

- **Type:** `boolean`
- **Default:** `false`

Enable Raycast configuration management. When enabled, the module generates a `.rayconfig` file at the specified output path.

#### `programs.raycast.version`

- **Type:** `string`
- **Default:** `"1.0.0"`

Raycast version string included in the generated configuration metadata.

#### `programs.raycast.installationDate`

- **Type:** `string`
- **Default:** `"2024-01-01T00:00:00Z"`

Installation timestamp in ISO 8601 format.

#### `programs.raycast.anonymousId`

- **Type:** `string`
- **Default:** `"00000000-0000-0000-0000-000000000000"`

Anonymous identifier (UUID format).

### Configuration Sources

These options are mutually exclusive, with priority order: `configFile` > `settings` > declarative options.

#### `programs.raycast.configFile`

- **Type:** `null or path`
- **Default:** `null`
- **Example:** `./raycast-export.json`

Path to a JSON file containing complete Raycast configuration. This is the recommended approach for importing existing configurations.

#### `programs.raycast.settings`

- **Type:** `null or attribute set`
- **Default:** `null`

Complete Raycast configuration as a Nix attribute set. Use this when you need to programmatically manipulate configuration.

### Declarative Options

#### `programs.raycast.preferences`

- **Type:** `attribute set`
- **Default:** `{}`

Structured Raycast preferences organized into three categories:

**`preferences.general`**
- `globalHotkey` (string): Keyboard shortcut (e.g., "Command-49")
- `alternativeEscape` (boolean): Enable alternative escape behavior

**`preferences.appearance`**
- `statusBarVisible` (boolean): Show Raycast in menu bar
- `textSize` (enum): "small" | "medium" | "large"
- `windowMode` (enum): "default" | "compact"
- `showFavoritesInCompactMode` (boolean)

**`preferences.advanced`**
- `windowPresentationMode` (integer): Window presentation mode
- `navigationStyle` (string): Navigation command style
- `popToRootTimeout` (integer): Timeout in seconds
- `keepWindowVisibleOnResign` (boolean)

#### `programs.raycast.snippets`

- **Type:** `list of attribute sets`
- **Default:** `[]`

Text snippets configuration. Each snippet requires:
- `name` (string): Display name
- `text` (string): Snippet content
- `keyword` (string): Trigger keyword

#### `programs.raycast.fallbackSearches`

- **Type:** `list of strings`
- **Default:** (includes file search, emoji search, etc.)

List of enabled fallback search identifiers.

#### `programs.raycast.installedExtensions`

- **Type:** `list of strings`
- **Default:** `[]`

Native extension identifiers to mark as installed.

#### `programs.raycast.floatingNotes`

- **Type:** `list of attribute sets`
- **Default:** `[]`

Floating notes configuration.

#### `programs.raycast.extraConfig`

- **Type:** `attribute set`
- **Default:** `{}`

Additional configuration merged into the generated JSON. Use this for package-specific settings not covered by other options.

### Security Options

#### `programs.raycast.encryptionPassword`

- **Type:** `null or string`
- **Default:** `null`

Password for encrypting the `.rayconfig` file using Scrypt + AES-256-GCM. When null, the file is generated unencrypted (gzip only).

### Automation Options

#### `programs.raycast.automationHotkey`

- **Type:** `string`
- **Default:** `"option down"`

AppleScript key modifier for automated import. Must match your Raycast global hotkey configuration.

#### `programs.raycast.outputPath`

- **Type:** `string`
- **Default:** `"$HOME/.config/raycast/import.rayconfig"`

Output path for the generated `.rayconfig` file.

## Technical Specification

### File Format

The `.rayconfig` file is a gzipped JSON file with the following structure:

```json
{
  "exportedAt": "2026-05-27T06:38:52.663Z",
  "appVersion": "0.61.0.0",
  "osName": "macOS",
  "osVersion": "26.5.0",
  "osArch": "arm64",
  "schemaVersion": 2,
  "data": "<hex-encoded encrypted data>",
  "encryption": {
    "iv": "<hex-encoded initialization vector>",
    "salt": "<hex-encoded salt>",
    "authTag": "<hex-encoded authentication tag>"
  }
}
```

### Encryption Process

When encryption is enabled:

1. **Compress:** The configuration JSON is gzipped
2. **Derive Key:** Scrypt key derivation with parameters:
   - N = 16384
   - r = 8
   - p = 1
   - Key length = 32 bytes
3. **Encrypt:** AES-256-GCM encryption with:
   - 12-byte random initialization vector
   - 16-byte random salt
   - 16-byte authentication tag
4. **Encode:** Ciphertext and metadata are hex-encoded
5. **Wrap:** Metadata wrapper JSON is created
6. **Compress:** Final JSON is gzipped to produce `.rayconfig`

### Unencrypted Format

For unencrypted configurations:

1. Configuration JSON is gzipped and hex-encoded
2. Placed in the `data` field without encryption metadata
3. Wrapper JSON is gzipped to produce `.rayconfig`

Both encrypted and unencrypted `.rayconfig` files can be imported by Raycast.

## Troubleshooting

### Build Failures

**Module not found or import errors**

Ensure nixkit is properly added to your flake inputs and imported in your Home Manager configuration:

```nix
imports = [ nixkit.homeManagerModules.default ];
```

**Python dependency errors**

The module requires Python 3 with the `cryptography` library. This is automatically provided by Nix and should not require manual intervention.

### Import Issues

**Automated import not working**

1. Verify Accessibility permissions:
   - Open System Settings → Privacy & Security → Accessibility
   - Grant permission to your terminal emulator (Terminal, iTerm2, etc.)

2. Confirm hotkey configuration matches Raycast settings:
   ```nix
   programs.raycast.automationHotkey = "option down";
   ```

3. Verify the configuration file exists:
   ```bash
   ls -lh ~/.config/raycast/import.rayconfig
   ```

4. Test file validity:
   ```bash
   raycast-decrypt-config ~/.config/raycast/import.rayconfig
   ```

5. Fall back to manual import if automation fails

**Import fails with decryption error**

If Raycast reports a decryption error:

1. Verify the password is correct:
   ```bash
   raycast-decrypt-config ~/.config/raycast/import.rayconfig your-password
   ```

2. Check the file is not corrupted:
   ```bash
   gunzip -c ~/.config/raycast/import.rayconfig | jq .
   ```

3. Regenerate the configuration with `home-manager switch`

### Decryption Errors

**Wrong password**

Ensure you're using the correct password from the original export:

```bash
raycast-decrypt-config export.rayconfig CORRECT_PASSWORD output.json
```

**Corrupted file**

Verify the file is valid gzipped JSON:

```bash
gunzip -c export.rayconfig | jq empty
```

### Configuration Issues

**Settings not applying**

The module generates `.rayconfig` files but does not automatically import them. You must:

1. Run `home-manager switch` to generate the file
2. Import the file into Raycast (automated or manual)
3. Restart Raycast if settings don't take effect immediately

**Encryption password stored in plain text**

The `encryptionPassword` option stores the password in the Nix store, which is world-readable. Consider:

- Using an unencrypted configuration if no sensitive data is present
- Managing secrets with a dedicated secrets management solution
- Understanding that the encryption primarily protects the file at rest, not in the Nix store

## Security Considerations

### Password Storage

The `encryptionPassword` option stores passwords in the Nix store, which is world-readable. This presents several security implications:

- **Nix Store Visibility:** All users on the system can read the Nix store
- **Build Logs:** Passwords may appear in build outputs
- **Git History:** Committed passwords remain in version control history

**Recommendations:**

1. **Omit encryption** if your configuration contains no sensitive data
2. **Use secrets management** solutions like sops-nix or agenix for production environments
3. **Understand the threat model:** The encryption primarily protects exported files, not the configuration source

### Sensitive Data

Raycast configurations may contain:

- API tokens for extensions
- Workspace identifiers
- Custom script contents
- Search history

Review your configuration before committing it to version control or sharing publicly.

## Related Projects

- [nixkit](https://github.com/frostplexx/nixkit) - NixOS modules collection containing this module
- [Home Manager](https://github.com/nix-community/home-manager) - User environment manager for NixOS
- [Raycast](https://raycast.com/) - Extensible macOS launcher

## References

- [Raycast Manual](https://manual.raycast.com/) - Official Raycast documentation
- [Import/Export Format Analysis](https://gist.github.com/jeremy-code/50117d5b4f29e04fcbbb1f55e301b893) - Community reverse-engineering of `.rayconfig` format
- [Home Manager Manual](https://nix-community.github.io/home-manager/) - Home Manager documentation

## Contributing

Issues and pull requests are welcome at the [nixkit repository](https://github.com/frostplexx/nixkit). When reporting issues, please include:

- Your NixOS and Home Manager versions
- Relevant configuration snippets
- Error messages or unexpected behavior
- Steps to reproduce

## License

This module is part of nixkit. See the main repository for license information.
