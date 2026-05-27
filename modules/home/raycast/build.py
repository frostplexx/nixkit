#!/usr/bin/env python3
"""
Build Raycast .rayconfig files from JSON configuration
Raycast uses Scrypt(N=16384, r=8, p=1) + AES-256-GCM + gzip compression
"""

import sys
import json
import gzip
import os
from pathlib import Path
from cryptography.hazmat.primitives.ciphers.aead import AESGCM
from cryptography.hazmat.primitives.kdf.scrypt import Scrypt


def build_rayconfig(config_json: str, password: str | None, output_file: str) -> None:
    """Build a .rayconfig file from JSON configuration"""

    # Read the input JSON
    with open(config_json, 'r') as f:
        config_data = json.load(f)

    if password:
        print("Creating encrypted .rayconfig with password...")

        # Generate random IV and salt
        iv = os.urandom(12)  # AES-GCM uses 12-byte IV
        salt = os.urandom(16)

        # Convert config to JSON and gzip it
        config_bytes = json.dumps(config_data, separators=(',', ':')).encode('utf-8')
        gzipped_data = gzip.compress(config_bytes)

        # Derive key using Scrypt (same parameters as Raycast)
        print("Deriving encryption key (Scrypt N=16384, r=8, p=1)...")
        key = Scrypt(salt=salt, length=32, n=16384, r=8, p=1).derive(password.encode())

        # Encrypt with AES-256-GCM
        aesgcm = AESGCM(key)
        encrypted = aesgcm.encrypt(iv, gzipped_data, None)

        # AES-GCM appends the auth tag to the ciphertext
        # We need to separate them for the Raycast format
        auth_tag_len = 16  # AES-GCM uses 16-byte auth tag
        ciphertext = encrypted[:-auth_tag_len]
        auth_tag = encrypted[-auth_tag_len:]

        # Build the wrapper JSON with encryption metadata
        wrapper = {
            "schemaVersion": 2,
            "encryption": {
                "algorithm": "aes-256-gcm",
                "iv": iv.hex(),
                "salt": salt.hex(),
                "authTag": auth_tag.hex()
            },
            "data": ciphertext.hex()
        }

        # Gzip the wrapper JSON to create the .rayconfig file
        wrapper_json = json.dumps(wrapper, separators=(',', ':')).encode('utf-8')
        with gzip.open(output_file, 'wb') as f:
            f.write(wrapper_json)

        print(f"✓ Successfully created encrypted .rayconfig: {output_file}")
    else:
        print("Creating unencrypted .rayconfig (gzipped only)...")

        # For unencrypted, we still need the wrapper format but without encryption
        wrapper = {
            "schemaVersion": 2,
            "data": json.dumps(config_data, separators=(',', ':'))
        }

        # Gzip the wrapper JSON
        wrapper_json = json.dumps(wrapper, separators=(',', ':')).encode('utf-8')
        with gzip.open(output_file, 'wb') as f:
            f.write(wrapper_json)

        print(f"✓ Successfully created unencrypted .rayconfig: {output_file}")

    file_size = Path(output_file).stat().st_size
    print(f"\nFile size: {file_size} bytes")
    print("\nTo import into Raycast:")
    print("  1. Open Raycast")
    print("  2. Go to Settings → Advanced")
    print("  3. Click 'Import Settings & Data'")
    print(f"  4. Select: {output_file}")
    print("\nOr use the automation script:")
    print("  raycast-import-config")


def main():
    if len(sys.argv) < 2:
        print("Usage: build.py <config.json> [password] [output.rayconfig]")
        print("")
        print("Build a Raycast .rayconfig file from JSON configuration")
        print("")
        print("Arguments:")
        print("  config.json        Path to the JSON configuration file")
        print("  password           Encryption password (optional, omit for unencrypted)")
        print("  output.rayconfig   Output file path (default: config.rayconfig)")
        print("")
        print("Examples:")
        print("  build.py config.json                           # Unencrypted")
        print("  build.py config.json 12345678                  # Encrypted")
        print("  build.py config.json mysecret output.rayconfig # Custom output path")
        sys.exit(1)

    config_json = sys.argv[1]
    password = sys.argv[2] if len(sys.argv) > 2 and sys.argv[2] else None
    output_file = sys.argv[3] if len(sys.argv) > 3 else "config.rayconfig"

    if not Path(config_json).exists():
        print(f"Error: Input file not found: {config_json}")
        sys.exit(1)

    try:
        build_rayconfig(config_json, password, output_file)
    except Exception as e:
        print(f"✗ Error: {e}")
        import traceback
        traceback.print_exc()
        sys.exit(1)


if __name__ == "__main__":
    main()
