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

    if not password:
        # Unencrypted: wrap in schemaVersion 2 format and gzip
        print("Creating unencrypted .rayconfig (gzipped only)...")

        # Build wrapper with data field (unencrypted)
        wrapper = {
            "schemaVersion": 2,
            "data": json.dumps(data, separators=(',', ':'))
        }

        # Gzip the wrapper JSON
        with gzip.open(output_file, 'wt') as f:
            json.dump(wrapper, f, separators=(',', ':'))

        print(f"✓ Successfully created: {output_file} (unencrypted)")
    else:
        # Encrypted: gzip, encrypt with Scrypt + AES-256-GCM
        print("Creating encrypted .rayconfig with password...")

        try:
            # Read and gzip the JSON
            with open(input_file, 'r') as f:
                json_data = f.read()

            compressed = gzip.compress(json_data.encode('utf-8'))

            # Generate random IV and salt
            iv = secrets.token_bytes(12)  # AES-GCM uses 12-byte IV
            salt = secrets.token_bytes(16)

            # Derive key using Scrypt (same parameters as Raycast)
            key = Scrypt(salt=salt, length=32, n=16384, r=8, p=1).derive(password.encode())

            # Encrypt using AES-256-GCM
            aesgcm = AESGCM(key)
            ciphertext = aesgcm.encrypt(iv, compressed, None)

            # Split ciphertext and auth tag (last 16 bytes)
            encrypted_data = ciphertext[:-16]
            auth_tag = ciphertext[-16:]

            # Build the config structure with encryption metadata
            config = {
                "schemaVersion": 2,
                "encryption": {
                    "algorithm": "aes-256-gcm",
                    "iv": iv.hex(),
                    "salt": salt.hex(),
                    "authTag": auth_tag.hex()
                },
                "data": encrypted_data.hex()
            }

            # Write as gzipped JSON
            with gzip.open(output_file, 'wt') as f:
                json.dump(config, f)

            print(f"✓ Successfully created: {output_file} (encrypted)")

        except Exception as e:
            print(f"✗ Error: Encryption failed: {e}")
            sys.exit(1)

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
