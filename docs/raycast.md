# Raycast NixOS Module

A Home Manager module for declaratively managing Raycast configuration using its native `.rayconfig` format.

## Features

- ✅ Declarative configuration of Raycast settings
- ✅ Import existing Raycast exports (JSON files)
- ✅ Build `.rayconfig` files from Nix expressions
- ✅ Support for both encrypted and unencrypted configs
- ✅ Helper scripts **always available** (decrypt/encrypt)
- ✅ **Automated import** via AppleScript (no manual clicking!)
- ✅ Full control over preferences, snippets, and extensions
- ✅ Three import modes: JSON file, attribute set, or declarative

## Quick Start

### 1. Enable the module

Add to your Home Manager configuration:

```nix
{
  programs.raycast = {
    enable = true;

    # Basic preferences
    preferences = {
      general.globalHotkey = "Option-49"; # Option+Space
      appearance.textSize = "medium";
    };

    # Add snippets
    snippets = [
      {
        name = "Email";
        text = "user@example.com";
        keyword = "email";
      }
    ];
  };
}
```

### 2. Apply configuration

```bash
home-manager switch
```

### 3. Import into Raycast (Automated!)

```bash
# Use the helper script - it will automate the entire process!
raycast-import-config

# The script will:
# 1. Open Raycast
# 2. Navigate to "Import Settings & Data"
# 3. Automatically select your config file
# 4. All you need to do is confirm the import!

# Or manually in Raycast:
# Settings → Advanced → Import Data → Select ~/.config/raycast/import.rayconfig
```

## Usage Examples

### Declarative Configuration

```nix
programs.raycast = {
  enable = true;
  version = "1.79.1";

  preferences = {
    general = {
      globalHotkey = "Command-49";  # Cmd+Space
      alternativeEscape = false;
    };

    appearance = {
      statusBarVisible = true;
      textSize = "medium";          # "small" | "medium" | "large"
      windowMode = "default";       # "default" | "compact"
    };

    advanced = {
      navigationStyle = "macos";
      popToRootTimeout = 90;
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

  # Optional: encrypt the config
  encryptionPassword = "12345678";
};
```

### Import from JSON File (Recommended)

```nix
programs.raycast = {
  enable = true;
  
  # Simply point to a JSON file
  configFile = ./raycast-export.json;
  
  # Optionally re-encrypt
  encryptionPassword = "12345678";
};
```

### Import from Attribute Set

```nix
programs.raycast = {
  enable = true;
  
  # Import from exported JSON
  settings = builtins.fromJSON (builtins.readFile ./raycast-export.json);
  
  # Optionally re-encrypt
  encryptionPassword = "mysecret";
};
```

### Advanced with Extra Config

```nix
programs.raycast = {
  enable = true;
  
  preferences.general.globalHotkey = "Option-49";
  
  # Add custom package configurations
  extraConfig = {
    builtin_package_github = {
      provider_schemaVersion = 1;
      repositories = ["owner/repo1" "owner/repo2"];
    };
  };
};
```

## Helper Scripts

The module provides these helper scripts:

### `raycast-decrypt-config` ⭐ Always Available

Decrypt and inspect `.rayconfig` files. **Available even without enabling the module.**

```bash
# Decrypt with default password (12345678)
raycast-decrypt-config export.rayconfig

# Decrypt with custom password
raycast-decrypt-config export.rayconfig mysecret output.json

# Decrypt unencrypted file (just decompress)
raycast-decrypt-config export.rayconfig "" output.json
```

### `raycast-encrypt-config` ⭐ Always Available

Create `.rayconfig` files from JSON. **Available even without enabling the module.**

```bash
# Create unencrypted .rayconfig (gzipped only)
raycast-encrypt-config config.json

# Create encrypted .rayconfig
raycast-encrypt-config config.json 12345678

# Specify output path
raycast-encrypt-config config.json mysecret output.rayconfig
```

### `raycast-import-config` (Only when module is enabled)

**Automatically** opens Raycast and navigates to import your configuration using AppleScript automation.

```bash
raycast-import-config
```

**What it does:**
1. Activates Raycast
2. Opens Raycast search with your configured hotkey
3. Types "Import Settings & Data"
4. Presses Enter
5. Attempts to automatically select your config file using UI scripting

**Requirements:**
- macOS Accessibility permissions for Terminal/your shell
- `automationHotkey` must match your actual Raycast hotkey

**Configuration:**
```nix
programs.raycast = {
  automationHotkey = "option down"; # Change to match your hotkey
  # "option down"   - Option+Space (default)
  # "command down"  - Cmd+Space
  # "control down"  - Ctrl+Space
};
```

## Exporting from Raycast

To export your current Raycast configuration for use with this module:

1. In Raycast, run: **Export Settings & Data**
2. Leave the password **blank** for unencrypted export (or use a password)
3. Save the `.rayconfig` file (e.g., `~/Downloads/Raycast-2026-05-27.rayconfig`)
4. Decrypt it using the helper script:
   ```bash
   raycast-decrypt-config ~/Downloads/Raycast-2026-05-27.rayconfig
   # Output: Raycast-2026-05-27.json
   ```
5. Use in your Nix config:
   ```nix
   # Option 1: Direct file path (simplest)
   programs.raycast.configFile = ./Raycast-2026-05-27.json;
   
   # Option 2: Attribute set
   programs.raycast.settings = builtins.fromJSON (builtins.readFile ./Raycast-2026-05-27.json);
   ```

## Configuration Options

### `programs.raycast.enable`
- **Type**: `boolean`
- **Default**: `false`
- Enable Raycast configuration management

### `programs.raycast.version`
- **Type**: `string`
- **Default**: `"1.0.0"`
- Raycast version string

### `programs.raycast.preferences`
- **Type**: `attribute set`
- Configure Raycast preferences (general, appearance, advanced)

### `programs.raycast.snippets`
- **Type**: `list of attribute sets`
- **Default**: `[]`
- Define text snippets

### `programs.raycast.configFile`
- **Type**: `null or path`
- **Default**: `null`
- **Example**: `./raycast-export.json`
- Path to a JSON file containing Raycast configuration (takes precedence over all other options)

### `programs.raycast.settings`
- **Type**: `null or attribute set`
- **Default**: `null`
- Complete Raycast configuration as attribute set (takes precedence over declarative options)

### `programs.raycast.encryptionPassword`
- **Type**: `null or string`
- **Default**: `null`
- Password for AES-256-CBC encryption (omit for unencrypted)

### `programs.raycast.automationHotkey`
- **Type**: `string`
- **Default**: `"option down"`
- **Example**: `"command down"`
- AppleScript modifier keys for automation (must match your Raycast hotkey)

### `programs.raycast.outputPath`
- **Type**: `string`
- **Default**: `"$HOME/.config/raycast/import.rayconfig"`
- Where to place the generated config file

## Format Details

The `.rayconfig` format consists of:

1. **Unencrypted**: Gzipped JSON
   ```bash
   cat config.json | gzip > config.rayconfig
   ```

2. **Encrypted**: 16-byte header + Gzipped JSON, encrypted with AES-256-CBC
   ```bash
   cat config.json | gzip | cat header.bin - | openssl enc -aes-256-cbc -k "password"
   ```

Raycast can import both encrypted and unencrypted `.rayconfig` files.

## Troubleshooting

### Automated import not working

1. **Check Accessibility permissions:**
   - System Settings → Privacy & Security → Accessibility
   - Enable for Terminal, iTerm2, or your shell

2. **Verify hotkey matches:**
   ```nix
   programs.raycast.automationHotkey = "option down"; # Must match your actual Raycast hotkey
   ```

3. **Check the file exists:**
   ```bash
   ls -lh ~/.config/raycast/import.rayconfig
   ```

4. **Verify it's valid:**
   ```bash
   raycast-decrypt-config ~/.config/raycast/import.rayconfig
   ```

5. **Try manual import** in Raycast UI if automation fails

### Wrong password error

If you exported with a password, decrypt manually:
```bash
raycast-decrypt-config export.rayconfig YOUR_PASSWORD output.json
```

## References

- [GitHub Gist: Import/export Raycast preferences](https://gist.github.com/jeremy-code/50117d5b4f29e04fcbbb1f55e301b893)
- [Raycast Settings Export Documentation](https://manual.raycast.com/)

## License

This module is part of nixkit and follows the same license.
