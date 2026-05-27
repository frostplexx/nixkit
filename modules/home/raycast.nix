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

  # Build the .rayconfig file
  mkRayconfig = configJson: encryptPassword:
    pkgs.runCommand "raycast.rayconfig" {
      nativeBuildInputs = with pkgs; [gzip openssl];
      json = builtins.toJSON configJson;
      passAsFile = ["json"];
    } (if encryptPassword != null then ''
      # Encrypted .rayconfig format
      # 1. Gzip the JSON
      # 2. Add a 16-byte header (using a pristine export header)
      # 3. Encrypt with AES-256-CBC

      # Create a dummy 16-byte header (Raycast format marker)
      printf '\x1f\x8b\x08\x00\x00\x00\x00\x00\x00\x00' > header.bin
      printf '\x00\x00\x00\x00\x00\x00' >> header.bin

      cat "$jsonPath" | gzip | cat header.bin - | \
        openssl enc -e -aes-256-cbc -nosalt -k "${encryptPassword}" -out "$out"
    '' else ''
      # Unencrypted .rayconfig format (just gzipped JSON)
      gzip -c "$jsonPath" > "$out"
    '');

  # Determine the final config to use
  finalConfig =
    if cfg.configFile != null then
      # Load from JSON file
      builtins.fromJSON (builtins.readFile cfg.configFile)
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
      home.packages = [
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

          # Create a Python script to handle decryption
          # Raycast uses Scrypt (not PBKDF2) + AES-256-GCM + gzip compression
          ${pkgs.python3.withPackages (ps: [ps.cryptography])}/bin/python3 - "$INPUT_FILE" "$PASSWORD" "$OUTPUT_FILE" <<'PYTHON'
          import sys
          import json
          import gzip
          from pathlib import Path

          try:
              from cryptography.hazmat.primitives.ciphers.aead import AESGCM
              from cryptography.hazmat.primitives.kdf.scrypt import Scrypt
              has_crypto = True
          except ImportError:
              has_crypto = False

          input_file = sys.argv[1]
          password = sys.argv[2]
          output_file = sys.argv[3]

          # Read and decompress the .rayconfig file
          try:
              with gzip.open(input_file, 'rt') as f:
                  config = json.load(f)
          except gzip.BadGzipFile:
              # Already decompressed JSON
              with open(input_file, 'r') as f:
                  config = json.load(f)

          # Check if data field is encrypted (has encryption metadata)
          if 'encryption' in config and config.get('data'):
              if not has_crypto:
                  print("✗ Error: File is encrypted but cryptography module is not available")
                  print("Install with: pip install cryptography")
                  sys.exit(1)

              if not password:
                  print("✗ Error: File is encrypted but no password provided")
                  sys.exit(1)

              print("Decrypting data field (using Scrypt + AES-256-GCM)...")

              try:
                  # Extract encryption parameters
                  enc = config['encryption']
                  iv = bytes.fromhex(enc['iv'])
                  salt = bytes.fromhex(enc['salt'])
                  auth_tag = bytes.fromhex(enc['authTag'])
                  encrypted_data = bytes.fromhex(config['data'])

                  # Raycast uses Scrypt(N=16384, r=8, p=1) for key derivation
                  key = Scrypt(salt=salt, length=32, n=16384, r=8, p=1).derive(password.encode())

                  # Decrypt using AES-256-GCM
                  ciphertext_with_tag = encrypted_data + auth_tag
                  aesgcm = AESGCM(key)
                  decrypted = aesgcm.decrypt(iv, ciphertext_with_tag, None)

                  # Raycast gzips the data before encrypting
                  try:
                      plaintext = gzip.decompress(decrypted).decode('utf-8')
                  except:
                      plaintext = decrypted.decode('utf-8')

                  # Parse and write the decrypted JSON
                  decrypted_data = json.loads(plaintext)
                  with open(output_file, 'w') as f:
                      json.dump(decrypted_data, f, indent=2)

                  print(f"✓ Successfully decrypted to: {output_file}")
                  print(f"\nFile size: {Path(output_file).stat().st_size} bytes")
                  print("To use with this module:")
                  print(f"  programs.raycast.configFile = ./{Path(output_file).name};")

              except Exception as e:
                  print(f"✗ Error: Decryption failed: {e}")
                  print("\nPossible causes:")
                  print("  - Wrong password")
                  print("  - Corrupted encrypted data")
                  print("  - Unsupported encryption format")
                  sys.exit(1)
          else:
              # No encryption, data is already plain JSON
              print("File is not encrypted (no encryption metadata found)")
              if 'data' in config:
                  print("⚠ Warning: File has 'data' field but no encryption metadata")
                  print("This might be an unsupported format")

              # Just write the config as-is
              with open(output_file, 'w') as f:
                  json.dump(config, f, indent=2)

              print(f"✓ Successfully wrote to: {output_file}")
              print(f"\nFile size: {Path(output_file).stat().st_size} bytes")
              print("To use with this module:")
              print(f"  programs.raycast.configFile = ./{Path(output_file).name};")
          PYTHON

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

          # Validate JSON
          if ! ${pkgs.jq}/bin/jq empty "$INPUT_FILE" 2>/dev/null; then
            echo "Error: Invalid JSON file"
            exit 1
          fi

          echo "Creating .rayconfig from $INPUT_FILE..."

          if [ -z "$PASSWORD" ]; then
            # Unencrypted: just gzip the JSON
            echo "Creating unencrypted .rayconfig (gzipped only)..."
            ${pkgs.gzip}/bin/gzip -c "$INPUT_FILE" > "$OUTPUT_FILE"
            echo "✓ Successfully created: $OUTPUT_FILE (unencrypted)"
          else
            # Encrypted: gzip, add header, then encrypt with AES-256-CBC
            echo "Creating encrypted .rayconfig with password..."

            # Create a 16-byte header (Raycast format marker)
            HEADER_FILE=$(mktemp)
            printf '\x1f\x8b\x08\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00' > "$HEADER_FILE"

            # Gzip the JSON, prepend header, then encrypt
            cat "$INPUT_FILE" | ${pkgs.gzip}/bin/gzip | cat "$HEADER_FILE" - | \
              ${pkgs.openssl}/bin/openssl enc -e -aes-256-cbc -nosalt -k "$PASSWORD" -out "$OUTPUT_FILE"

            rm "$HEADER_FILE"
            echo "✓ Successfully created: $OUTPUT_FILE (encrypted)"
          fi

          echo ""
          echo "File size: $(wc -c < "$OUTPUT_FILE") bytes"
          echo ""
          echo "To import into Raycast:"
          echo "  1. Open Raycast"
          echo "  2. Go to Settings → Advanced"
          echo "  3. Click 'Import Data'"
          echo "  4. Select: $OUTPUT_FILE"
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

      # Import script (only when module is enabled)
      home.packages = [
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
