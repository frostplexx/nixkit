#!/usr/bin/env bash
set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

log_info() {
  echo -e "${BLUE}🔍 $1${NC}"
}

log_success() {
  echo -e "${GREEN}✅ $1${NC}"
}

log_warning() {
  echo -e "${YELLOW}⚠️  $1${NC}"
}

log_error() {
  echo -e "${RED}❌ $1${NC}"
}

# Check if we're in a git repository
if ! git rev-parse --git-dir >/dev/null 2>&1; then
  log_error "Not in a git repository!"
  exit 1
fi

# Check if working directory is clean (staged or unstaged changes)
if ! git diff-index --quiet HEAD -- || ! git diff --quiet --cached; then
  log_warning "Working directory has uncommitted changes."
  read -p "Continue anyway? (y/N): " -n 1 -r
  echo
  if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    log_info "Aborted by user."
    exit 0
  fi
fi

log_info "Discovering packages..."

# Get all packages from the flake
packages=$(nix eval --json .#packages.$(nix eval --impure --raw --expr 'builtins.currentSystem') --apply 'builtins.attrNames' | jq -r '.[]')

if [ -z "$packages" ]; then
  log_error "No packages found in flake!"
  exit 1
fi

log_info "Found packages: $(echo $packages | tr '\n' ' ')"
echo

# Track results
declare -a successful_updates=()
declare -a failed_updates=()
declare -a skipped_updates=()

# Update each package
for package in $packages; do
  echo -e "${BLUE}🔄 Updating $package...${NC}"

  # Capture output and exit code
  if output=$(nix-update "$package" --build --commit -vr ".*([0-9]+\.[0-9]+\.[0-9]+).*" 2>&1); then
    # Check if there was actually an update by looking for version info in output
    if echo "$output" | grep -q "Update.*->.*in"; then
      # Extract version information
      version_info=$(echo "$output" | grep "Update.*->.*in" | head -1 | sed 's/.*Update \(.*\) in.*/\1/')
      log_success "Successfully updated $package ($version_info)"
      successful_updates+=("$package")
    elif echo "$output" | grep -q "No changes detected"; then
      log_warning "$package is already up to date"
      skipped_updates+=("$package")
    else
      log_success "Successfully updated $package"
      successful_updates+=("$package")
    fi
  else
    exit_code=$?
    if [ $exit_code -eq 2 ]; then
      log_warning "$package is already up to date"
      skipped_updates+=("$package")
    elif echo "$output" | grep -q "Could not find a url in the derivations src attribute"; then
      log_warning "$package: Cannot update (no URL in src - likely local source)"
      skipped_updates+=("$package")
    elif echo "$output" | grep -q "No changes detected"; then
      log_warning "$package is already up to date"
      skipped_updates+=("$package")
    else
      log_error "Failed to update $package (exit code: $exit_code)"
      echo "$output" | head -5 # Show first few lines of error for debugging
      failed_updates+=("$package")
    fi
  fi
  echo
done

# Summary
echo "========================================="
echo -e "${BLUE}📊 Update Summary${NC}"
echo "========================================="

if [ ${#successful_updates[@]} -gt 0 ]; then
  log_success "Successfully updated (${#successful_updates[@]}):"
  for package in "${successful_updates[@]}"; do
    echo "  ✅ $package"
  done
  echo
fi

if [ ${#skipped_updates[@]} -gt 0 ]; then
  log_warning "Skipped (${#skipped_updates[@]}):"
  for package in "${skipped_updates[@]}"; do
    echo "  ⏭️  $package"
  done
  echo
fi

if [ ${#failed_updates[@]} -gt 0 ]; then
  log_error "Failed to update (${#failed_updates[@]}):"
  for package in "${failed_updates[@]}"; do
    echo "  ❌ $package"
  done
  echo
  log_error "Some packages failed to update. Check the output above for details."
  exit 1
fi

if [ ${#successful_updates[@]} -gt 0 ]; then
  echo -e "${GREEN}🎉 All updates completed successfully!${NC}"
  echo -e "${BLUE}💡 Don't forget to push your changes: git push${NC}"
else
  echo -e "${BLUE}✨ All packages are already up to date!${NC}"
fi
