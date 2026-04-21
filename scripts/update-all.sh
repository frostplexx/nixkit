#!/usr/bin/env bash
set -euo pipefail
# Thin wrapper to update all packages for the current system
# Detect current system
case "$(uname -s)" in
  Linux)  os="linux" ;;
  Darwin) os="darwin" ;;
  *)      echo "Unsupported OS: $(uname -s)"; exit 1 ;;
esac
# Get all packages for this system that have updateScript
packages=$(nix eval --json '.#packages' --apply 'builtins.mapAttrs (system: pkgs: builtins.attrNames pkgs)' | \
  jq -r --arg os "$os" '
    to_entries[] 
    | select(.key | contains($os)) 
    | .value[]
  ' | sort -u)
# Check which packages have updateScript (use aarch64-darwin as reference)
updatable=()
for pkg in $packages; do
  if nix eval --json ".#packages.aarch64-darwin.$pkg.passthru.updateScript" 2>/dev/null >/dev/null; then
    updatable+=("$pkg")
  fi
done
if [ ${#updatable[@]} -eq 0 ]; then
  echo "No updatable packages found"
  exit 0
fi
echo "Updating packages: ${updatable[*]}"
exec "$(dirname "$0")/update.py" --os "$os" --packages "${updatable[@]}" "$@"
