#!/usr/bin/env python3
"""
Encrypt JSON files to Raycast .rayconfig format
Raycast uses Scrypt(N=16384, r=8, p=1) + AES-256-GCM + gzip compression
"""

import sys
import json
import gzip
import secrets
from pathlib import Path
from cryptography.hazmat.primitives.ciphers.aead import AESGCM
from cryptography.hazmat.primitives.kdf.scrypt import Scrypt


def encrypt_rayconfig(input_file: str, password: str | None, output_file: str) -> None:
    """Encrypt a JSON file to Raycast .rayconfig format"""

    # Validate JSON
    try:
        with open(input_file, 'r') as f:
            data = json.load(f)
    except json.JSONDecodeError:
        print("Error: Invalid JSON file")
        sys.exit(1)

    print(f"Creating .rayconfig from {input_file}...")

    # Convert config to JSON and gzip it
    config_bytes = json.dumps(data, separators=(',', ':')).encode('utf-8')
    gzipped_data = gzip.compress(config_bytes)

    if password:
        # Encrypted: gzip then encrypt with Scrypt + AES-256-GCM
        print("Creating encrypted .rayconfig with password...")

        try:
            # Generate random IV and salt
            iv = secrets.token_bytes(12)  # AES-GCM uses 12-byte IV
            salt = secrets.token_bytes(16)

            # Derive key using Scrypt (same parameters as Raycast)
            key = Scrypt(salt=salt, length=32, n=16384, r=8, p=1).derive(password.encode())

            # Encrypt the gzipped data using AES-256-GCM
            aesgcm = AESGCM(key)
            encrypted = aesgcm.encrypt(iv, gzipped_data, None)

            # Split ciphertext and auth tag (last 16 bytes)
            encrypted_data = encrypted[:-16]
            auth_tag = encrypted[-16:]

            # Build the wrapper JSON with all metadata
            wrapper = {
                "exportedAt": "2026-01-01T00:00:00.000Z",
                "appVersion": "1.0.0",
                "osName": "macOS",
                "osVersion": "15.0.0",
                "osArch": "arm64",
                "schemaVersion": 2,
                "data": encrypted_data.hex(),
                "encryption": {
                    "iv": iv.hex(),
                    "salt": salt.hex(),
                    "authTag": auth_tag.hex()
                }
            }

            print(f"✓ Successfully created: {output_file} (encrypted)")

        except Exception as e:
            print(f"✗ Error: Encryption failed: {e}")
            sys.exit(1)
    else:
        # Unencrypted: data field contains gzipped config as hex
        print("Creating unencrypted .rayconfig...")

        wrapper = {
            "exportedAt": "2026-01-01T00:00:00.000Z",
            "appVersion": "1.0.0",
            "osName": "macOS",
            "osVersion": "15.0.0",
            "osArch": "arm64",
            "schemaVersion": 2,
            "data": gzipped_data.hex()
        }

        print(f"✓ Successfully created: {output_file} (unencrypted)")

    # Gzip the wrapper JSON to create the .rayconfig file
    wrapper_json = json.dumps(wrapper, indent=2).encode('utf-8')
    with gzip.open(output_file, 'wb') as f:
        f.write(wrapper_json)

    print("")
    print(f"File size: {Path(output_file).stat().st_size} bytes")
    print("")
    print("To import into Raycast:")
    print("  1. Open Raycast")
    print("  2. Go to Settings → Advanced")
    print("  3. Click 'Import Data'")
    print(f"  4. Select: {output_file}")


def main():
    if len(sys.argv) < 2:
        print("Usage: raycast-encrypt.py <input.json> [password] [output.rayconfig]")
        print("")
        print("Encrypt a JSON file to Raycast .rayconfig format")
        print("")
        print("Arguments:")
        print("  input.json         Path to the JSON file")
        print("  password           Encryption password (optional, omit for unencrypted)")
        print("  output.rayconfig   Output file path (default: input name with .rayconfig)")
        print("")
        print("Examples:")
        print("  raycast-encrypt.py config.json                    # Unencrypted (gzip only)")
        print("  raycast-encrypt.py config.json 12345678           # Encrypted with password")
        print("  raycast-encrypt.py config.json mysecret out.rayconfig")
        sys.exit(1)

    input_file = sys.argv[1]
    password = sys.argv[2] if len(sys.argv) > 2 else None
    output_file = sys.argv[3] if len(sys.argv) > 3 else str(Path(input_file).with_suffix('.rayconfig'))

    if not Path(input_file).exists():
        print(f"Error: Input file not found: {input_file}")
        sys.exit(1)

    encrypt_rayconfig(input_file, password, output_file)


if __name__ == "__main__":
    main()
