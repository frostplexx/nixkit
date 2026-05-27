{
  config,
  lib,
  pkgs,
  ...
}:
with lib; let
  cfg = config.programs.raycast;

  # Build the complete Raycast configuration JSON
  raycastConfig = {
    raycast_version = cfg.version;
    raycast_app_defaults = {
      provider_schemaVersion = 1;
      firstKnownVersion = cfg.version;
      installationDate = cfg.installationDate;
      anonymousId = cfg.anonymousId;
    };

    builtin_package_raycastPreferences = {
      provider_schemaVersion = 1;
      preferencesGeneral = {
        raycastGlobalHotkey = cfg.preferences.general.globalHotkey;
        raycastAlternativeEscape = cfg.preferences.general.alternativeEscape;
      };
      preferencesAppearance = {
        statusBarIsVisible = cfg.preferences.appearance.statusBarVisible;
        raycastUI_preferredTextSize = cfg.preferences.appearance.textSize;
        raycastPreferredWindowMode = cfg.preferences.appearance.windowMode;
        showFavoritesInCompactMode = cfg.preferences.appearance.showFavoritesInCompactMode;
      };
      preferencesAdvanced = {
        raycastWindowPresentationMode = cfg.preferences.advanced.windowPresentationMode;
        navigationCommandStyleIdentifierKey = cfg.preferences.advanced.navigationStyle;
        popToRootTimeout = cfg.preferences.advanced.popToRootTimeout;
        keepWindowVisibleOnResignKey = cfg.preferences.advanced.keepWindowVisibleOnResign;
      };
    };

    # Default package configurations
    builtin_package_default = {
      provider_schemaVersion = 1;
      enabledFallbackSearchIdentifiers = cfg.fallbackSearches;
      installedNativeExtensionIdentifiers = cfg.installedExtensions;
    };

    builtin_package_snippets = {
      provider_schemaVersion = 1;
      snippets = cfg.snippets;
    };

    builtin_package_floatingNotes = {
      provider_schemaVersion = 1;
    } // optionalAttrs (cfg.floatingNotes != []) {
      notes = cfg.floatingNotes;
    };

    # Other built-in packages with default schema version
  } // (builtins.listToAttrs (map (pkg: {
    name = "builtin_package_${pkg}";
    value.provider_schemaVersion = 1;
  }) [
    "typingPractice" "raycastAccount" "fileSearch" "github" "quick-ai"
    "calendar" "dictionary" "scriptCommands" "emoji" "raycastExtensions"
    "navigation" "linear" "clipboardHistory" "webSearches" "browserBookmarks"
    "url" "reminders" "calculator" "contacts" "asana" "translator"
    "rootSearch" "nodeExtension" "developer" "gSuite" "organizations"
    "systemCommands" "jira" "screenshots" "zoom" "media"
  ])) // {
    raycast_onboarding = {
      provider_schemaVersion = 1;
      showOnboardingItem = false;
      completedTaskIdentifiers = [];
    };
  } // cfg.extraConfig;

  # Python environment and scripts
  pythonEnv = pkgs.python3.withPackages (ps: [ps.cryptography]);
  buildScript = ./build.py;

  # Build the .rayconfig file using the Python build script
  mkRayconfig = configJson: encryptPassword:
    pkgs.runCommand "raycast.rayconfig" {
      nativeBuildInputs = [pythonEnv];
      json = builtins.toJSON configJson;
      passAsFile = ["json"];
    } (if encryptPassword != null then ''
      # Build encrypted .rayconfig using Scrypt + AES-256-GCM
      ${pythonEnv}/bin/python3 ${buildScript} "$jsonPath" "${encryptPassword}" "$out"
    '' else ''
      # Build unencrypted .rayconfig (gzipped only)
      ${pythonEnv}/bin/python3 ${buildScript} "$jsonPath" "" "$out"
    '');

  # Determine the final config to use
  finalConfig =
    if cfg.configFile != null then
       let
         content = builtins.readFile cfg.configFile;
       in
         builtins.fromJSON content
    else if cfg.settings != null then
      # Use provided attribute set directly
      cfg.settings
    else if cfg.enable then
      # Build from declarative options
      raycastConfig
    else null;

  finalConfigFile =
    if finalConfig != null then
      mkRayconfig finalConfig cfg.encryptionPassword
    else null;

in {
  options.programs.raycast = {
    enable = mkEnableOption "Raycast configuration management";

    version = mkOption {
      type = types.str;
      default = "1.0.0";
      description = "Raycast version string";
    };

    installationDate = mkOption {
      type = types.str;
      default = "2024-01-01T00:00:00Z";
      description = "Installation date in ISO 8601 format";
    };

    anonymousId = mkOption {
      type = types.str;
      default = "00000000-0000-0000-0000-000000000000";
      description = "Anonymous ID (UUID)";
    };

    preferences = {
      general = {
        globalHotkey = mkOption {
          type = types.str;
          default = "Command-49";
          example = "Option-49";
          description = "Global hotkey to open Raycast (e.g., 'Command-49' for Cmd+Space)";
        };

        alternativeEscape = mkOption {
          type = types.bool;
          default = false;
          description = "Use alternative escape behavior";
        };
      };

      appearance = {
        statusBarVisible = mkOption {
          type = types.bool;
          default = true;
          description = "Show Raycast in menu bar";
        };

        textSize = mkOption {
          type = types.enum ["small" "medium" "large"];
          default = "medium";
          description = "Preferred text size";
        };

        windowMode = mkOption {
          type = types.enum ["default" "compact"];
          default = "default";
          description = "Window mode";
        };

        showFavoritesInCompactMode = mkOption {
          type = types.bool;
          default = true;
          description = "Show favorites in compact mode";
        };
      };

      advanced = {
        windowPresentationMode = mkOption {
          type = types.int;
          default = 0;
          description = "Window presentation mode (0 = default)";
        };

        navigationStyle = mkOption {
          type = types.str;
          default = "macos";
          description = "Navigation command style";
        };

        popToRootTimeout = mkOption {
          type = types.int;
          default = 90;
          description = "Pop to root timeout in seconds";
        };

        keepWindowVisibleOnResign = mkOption {
          type = types.bool;
          default = false;
          description = "Keep window visible when resigning";
        };
      };
    };

    fallbackSearches = mkOption {
      type = types.listOf types.str;
      default = [
        "builtin_command_fileSearch_fallbackSearch"
        "builtin_command_extensionStore_fallbackSearch"
        "builtin_command_searchSnippets_fallbackSearch"
        "builtin_command_dictionary_defineWord_fallbackSearch"
        "builtin_command_translate_fallbackSearch"
        "builtin_command_searchEmoji_fallbackSearch"
        "builtin_command_searchMenuItems_fallbackSearch"
      ];
      description = "Enabled fallback search identifiers";
    };

    installedExtensions = mkOption {
      type = types.listOf types.str;
      default = [];
      example = ["builtin_package_media"];
      description = "List of installed native extension identifiers";
    };

    snippets = mkOption {
      type = types.listOf types.attrs;
      default = [];
      example = literalExpression ''
        [
          {
            name = "Email";
            text = "user@example.com";
            keyword = "email";
          }
        ]
      '';
      description = "Raycast snippets";
    };

    floatingNotes = mkOption {
      type = types.listOf types.attrs;
      default = [];
      description = "Floating notes configuration";
    };

    extraConfig = mkOption {
      type = types.attrs;
      default = {};
      example = literalExpression ''
        {
          builtin_package_github = {
            provider_schemaVersion = 1;
            repositories = ["owner/repo"];
          };
        }
      '';
      description = "Extra configuration merged into the generated JSON";
    };

    configFile = mkOption {
      type = types.nullOr types.path;
      default = null;
      example = literalExpression "./raycast-config.json";
      description = ''
        Path to a JSON file containing Raycast configuration.
        This takes precedence over both `settings` and declarative options.

        The JSON file should be an exported Raycast configuration that has been
        decrypted and decompressed.

        Example:
          programs.raycast.configFile = ./raycast-export.json;
      '';
    };

    settings = mkOption {
      type = types.nullOr types.attrs;
      default = null;
      example = literalExpression ''
        {
          raycast_version = "1.79.1";
          builtin_package_raycastPreferences = {
            # ...
          };
        }
      '';
      description = ''
        Complete Raycast configuration as an attribute set.
        When set, this takes precedence over the declarative options.
        Use this to import an existing configuration exported from Raycast.

        Note: If `configFile` is set, it takes precedence over this option.
      '';
    };

    encryptionPassword = mkOption {
      type = types.nullOr types.str;
      default = null;
      example = "12345678";
      description = ''
        Password to encrypt the .rayconfig file with AES-256-CBC.
        If null, the file will be generated unencrypted (gzipped only).
        Raycast can import both encrypted and unencrypted files.
      '';
    };

    automationHotkey = mkOption {
      type = types.str;
      default = "option down";
      example = "command down";
      description = ''
        AppleScript modifier keys for the Raycast automation hotkey.
        Used by the raycast-import-config script to open Raycast.

        Common values:
        - "option down" for Option+Space
        - "command down" for Cmd+Space
        - "control down" for Ctrl+Space

        Must match your Raycast global hotkey setting.
      '';
    };

    outputPath = mkOption {
      type = types.str;
      default = "$HOME/.config/raycast/import.rayconfig";
      description = "Where to place the generated .rayconfig file";
    };
  };

  config = mkMerge [
    # Always provide helper scripts (even when module is disabled)
    {
      home.packages = let
        # Standalone Python scripts
        decryptScript = ./decrypt.py;
        encryptScript = ./encrypt.py;
      in [
        # Decrypt script (for inspecting encrypted configs)
        (pkgs.writeShellScriptBin "raycast-decrypt-config" ''
          set -euo pipefail

          if [ $# -lt 1 ]; then
            echo "Usage: raycast-decrypt-config <input.rayconfig> [password] [output.json]"
            echo ""
            echo "Decrypt a Raycast .rayconfig file to JSON"
            echo ""
            echo "Arguments:"
            echo "  input.rayconfig  Path to the .rayconfig file"
            echo "  password         Decryption password (default: 12345678, use empty string for unencrypted)"
            echo "  output.json      Output file path (default: input name with .json)"
            echo ""
            echo "Examples:"
            echo "  raycast-decrypt-config export.rayconfig"
            echo "  raycast-decrypt-config export.rayconfig mysecret output.json"
            echo "  raycast-decrypt-config export.rayconfig \"\" output.json  # for unencrypted"
            exit 1
          fi

          INPUT_FILE="$1"
          PASSWORD="''${2:-12345678}"
          OUTPUT_FILE="''${3:-$(basename "$INPUT_FILE" .rayconfig).json}"

          if [ ! -f "$INPUT_FILE" ]; then
            echo "Error: Input file not found: $INPUT_FILE"
            exit 1
          fi

          echo "Decrypting $INPUT_FILE..."

          # Call standalone Python script
          # Raycast uses Scrypt (not PBKDF2) + AES-256-GCM + gzip compression
          exec ${pythonEnv}/bin/python3 ${decryptScript} "$INPUT_FILE" "$PASSWORD" "$OUTPUT_FILE"

        '')

        # Encrypt script
        (pkgs.writeShellScriptBin "raycast-encrypt-config" ''
          set -euo pipefail

          if [ $# -lt 1 ]; then
            echo "Usage: raycast-encrypt-config <input.json> [password] [output.rayconfig]"
            echo ""
            echo "Encrypt a JSON file to Raycast .rayconfig format"
            echo ""
            echo "Arguments:"
            echo "  input.json         Path to the JSON file"
            echo "  password           Encryption password (optional, omit for unencrypted)"
            echo "  output.rayconfig   Output file path (default: input name with .rayconfig)"
            echo ""
            echo "Examples:"
            echo "  raycast-encrypt-config config.json                    # Unencrypted (gzip only)"
            echo "  raycast-encrypt-config config.json 12345678           # Encrypted with password"
            echo "  raycast-encrypt-config config.json mysecret out.rayconfig"
            exit 1
          fi

          INPUT_FILE="$1"
          PASSWORD="''${2:-}"
          OUTPUT_FILE="''${3:-$(basename "$INPUT_FILE" .json).rayconfig}"

          if [ ! -f "$INPUT_FILE" ]; then
            echo "Error: Input file not found: $INPUT_FILE"
            exit 1
          fi

          echo "Creating .rayconfig from $INPUT_FILE..."

          # Call standalone Python script
          # Raycast uses Scrypt + AES-256-GCM + gzip compression
          exec ${pythonEnv}/bin/python3 ${encryptScript} "$INPUT_FILE" "$PASSWORD" "$OUTPUT_FILE"

        '')
      ];
    }

    # Configuration management (only when enabled)
    (mkIf cfg.enable {
      assertions = [
        {
          assertion = finalConfig != null;
          message = "programs.raycast requires either configFile, settings, or declarative options to be set";
        }
      ];

      home.activation.raycastSetup = lib.hm.dag.entryAfter ["writeBoundary"] (
        optionalString (finalConfigFile != null) ''
          # Create Raycast config directory
          $DRY_RUN_CMD mkdir -p "$(dirname "${cfg.outputPath}")"

          # Copy the configuration file
          $DRY_RUN_CMD cp -f "${finalConfigFile}" "${cfg.outputPath}"

          # Make it readable
          $DRY_RUN_CMD chmod 644 "${cfg.outputPath}"

          $VERBOSE_ECHO "Raycast configuration generated at ${cfg.outputPath}"
          $VERBOSE_ECHO "To import: Raycast → Settings → Advanced → Import Data"
          $VERBOSE_ECHO "Or run: raycast-import-config"
        ''
      );

      # Install Raycast Beta application and import script
      home.packages = [
        pkgs.raycast-beta
        (pkgs.writeShellScriptBin "raycast-import-config" ''
          set -euo pipefail

          CONFIG_FILE="${cfg.outputPath}"

          if [ ! -f "$CONFIG_FILE" ]; then
            echo "Error: Configuration file not found at $CONFIG_FILE"
            echo "Run 'home-manager switch' first to generate the configuration."
            exit 1
          fi

          echo "Opening Raycast to import configuration..."
          echo "Configuration file: $CONFIG_FILE"
          echo ""

          # Use AppleScript to automate the import process
          osascript <<EOF
          -- Activate Raycast
          tell application "Raycast Beta" to activate
          delay 0.5

          -- Open Raycast Root Search using configured hotkey
          tell application "System Events"
            keystroke space using {${cfg.automationHotkey}}
          end tell
          delay 0.5

          -- Type the import command
          tell application "System Events"
            keystroke "Import Settings & Data"
            delay 0.5
            keystroke return
          end tell

          -- Wait for the import dialog to open
          delay 1.5

          -- Try to automate file selection using UI scripting
          tell application "System Events"
            tell process "Raycast Beta"
              -- Wait for file dialog to appear
              repeat 10 times
                if (count of windows) > 0 then exit repeat
                delay 0.3
              end repeat

              try
                -- Type the file path in the file dialog
                keystroke "g" using {command down, shift down}
                delay 0.5
                keystroke "$CONFIG_FILE"
                delay 0.3
                keystroke return
                delay 0.5
                keystroke return
              on error errMsg
                -- If automation fails, just open the directory
                do shell script "open -R '$CONFIG_FILE'"
              end try
            end tell
          end tell
          EOF

          echo ""
          echo "✓ Raycast import process initiated"
          echo ""
          echo "If the file was not automatically selected:"
          echo "  1. In the file picker, press: Cmd+Shift+G"
          echo "  2. Paste: $CONFIG_FILE"
          echo "  3. Press Enter twice"
        '')
      ];
    })
  ];
}
