# Example Raycast NixOS Module Configuration
#
# This module allows you to declaratively manage your Raycast configuration
# using Nix, and builds a .rayconfig file that can be imported into Raycast.
#
# Based on: https://gist.github.com/jeremy-code/50117d5b4f29e04fcbbb1f55e301b893

{
  # Example 1: Basic declarative configuration
  programs.raycast = {
    enable = true;

    # Basic metadata
    version = "1.79.1";
    installationDate = "2024-01-01T00:00:00Z";

    # Preferences
    preferences = {
      general = {
        globalHotkey = "Option-49"; # Option+Space
        alternativeEscape = false;
      };

      appearance = {
        statusBarVisible = true;
        textSize = "medium"; # "small" | "medium" | "large"
        windowMode = "default"; # "default" | "compact"
        showFavoritesInCompactMode = true;
      };

      advanced = {
        navigationStyle = "macos";
        popToRootTimeout = 90;
      };
    };

    # Automation hotkey for import script (must match your Raycast hotkey)
    automationHotkey = "option down"; # Change to "command down" for Cmd+Space

    # Snippets
    snippets = [
      {
        name = "Email";
        text = "user@example.com";
        keyword = "email";
      }
      {
        name = "Shrug";
        text = "¯\\_(ツ)_/¯";
        keyword = "shrug";
      }
    ];

    # Fallback searches (what appears when you search)
    fallbackSearches = [
      "builtin_command_fileSearch_fallbackSearch"
      "builtin_command_extensionStore_fallbackSearch"
      "builtin_command_searchSnippets_fallbackSearch"
      "builtin_command_searchEmoji_fallbackSearch"
    ];

    # Optional: Encrypt the config file
    # encryptionPassword = "12345678";
  };

  # Example 2: Import from JSON file (simplest method)
  # programs.raycast = {
  #   enable = true;
  #   configFile = ./raycast-export.json;
  #   # Optional: encrypt it
  #   encryptionPassword = "12345678";
  # };

  # Example 3: Import from attribute set
  # programs.raycast = {
  #   enable = true;
  #   settings = builtins.fromJSON (builtins.readFile ./raycast-export.json);
  #   encryptionPassword = "mysecretpassword";
  # };

  # Example 4: Advanced configuration with extra settings
  # programs.raycast = {
  #   enable = true;
  #
  #   preferences.general.globalHotkey = "Command-49";
  #
  #   extraConfig = {
  #     builtin_package_github = {
  #       provider_schemaVersion = 1;
  #       repositories = ["owner/repo1" "owner/repo2"];
  #     };
  #     builtin_package_linear = {
  #       provider_schemaVersion = 1;
  #       teams = ["TEAM-123"];
  #     };
  #   };
  # };
}

# Helper scripts are ALWAYS available (even without enabling the module):
#
# - raycast-decrypt-config: Decrypt .rayconfig files to JSON
# - raycast-encrypt-config: Encrypt JSON files to .rayconfig format
#
# When the module is enabled, you also get:
# - raycast-import-config: Import the generated config into Raycast

# After applying this configuration with `home-manager switch`:
#
# 1. The .rayconfig file will be generated at ~/.config/raycast/import.rayconfig
#
# 2. Import it into Raycast (AUTOMATED):
#    - Run: raycast-import-config
#    - The script will automatically:
#      * Open Raycast
#      * Navigate to "Import Settings & Data"
#      * Select your configuration file
#    - Or manually: Raycast → Settings → Advanced → Import Data
#
# 3. To inspect/decrypt a .rayconfig file:
#    raycast-decrypt-config ~/.config/raycast/import.rayconfig
#
# 4. To create a .rayconfig from JSON:
#    raycast-encrypt-config my-config.json [password]
#
# 5. To export your current Raycast settings for use with this module:
#    - Raycast → Settings → Extensions → Raycast → Export Settings & Data
#    - Leave password blank (or use a password and decrypt later)
#    - Save the file as exported.rayconfig, then:
#      raycast-decrypt-config exported.rayconfig "" exported.json
#    - Use with the module:
#      programs.raycast.configFile = ./exported.json;
