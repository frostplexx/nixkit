#!/usr/bin/env python3
"""
Decrypt Raycast .rayconfig files
Raycast uses Scrypt(N=16384, r=8, p=1) + AES-256-GCM + gzip compression
"""

import sys
import json
import gzip
from pathlib import Path
from cryptography.hazmat.primitives.ciphers.aead import AESGCM
from cryptography.hazmat.primitives.kdf.scrypt import Scrypt


def decrypt_rayconfig(input_file: str, password: str, output_file: str) -> None:
    """Decrypt a Raycast .rayconfig file to JSON"""

    # Read and decompress the .rayconfig file
    try:
        with gzip.open(input_file, 'rt') as f:
            config = json.load(f)
    except gzip.BadGzipFile:
        # Already decompressed JSON
        with open(input_file, 'r') as f:
            config = json.load(f)

    # Check if data field is encrypted (has encryption metadata)
    if 'encryption' not in config or not config.get('data'):
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
        return

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


def main():
    if len(sys.argv) < 2:
        print("Usage: raycast-decrypt.py <input.rayconfig> [password] [output.json]")
        print("")
        print("Decrypt a Raycast .rayconfig file to JSON")
        print("")
        print("Arguments:")
        print("  input.rayconfig  Path to the .rayconfig file")
        print("  password         Decryption password (default: 12345678, use empty string for unencrypted)")
        print("  output.json      Output file path (default: input name with .json)")
        print("")
        print("Examples:")
        print("  raycast-decrypt.py export.raycast")
        print("  raycast-decrypt.py export.raycast mysecret output.json")
        print('  raycast-decrypt.py export.raycast "" output.json  # for unencrypted')
        sys.exit(1)

    input_file = sys.argv[1]
    password = sys.argv[2] if len(sys.argv) > 2 else "12345678"
    output_file = sys.argv[3] if len(sys.argv) > 3 else str(Path(input_file).with_suffix('.json'))

    if not Path(input_file).exists():
        print(f"Error: Input file not found: {input_file}")
        sys.exit(1)

    decrypt_rayconfig(input_file, password, output_file)


if __name__ == "__main__":
    main()
