#!/bin/bash

set -e pipefail

# Locate the SDK path
default_sdk="$(xcrun --show-sdk-path)"
bin_name=hyperkey


swiftc \
    -sdk "$default_sdk" \
    -O \
    -framework Cocoa \
    -framework Carbon \
    -framework Foundation \
    hyperkey.swift \
    -o "$bin_name"


# Make the output executable
chmod +x "$bin_name"

echo "Build complete: ./$bin_name"
