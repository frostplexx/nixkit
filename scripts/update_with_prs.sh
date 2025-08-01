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

# Update each package in separate branches
for package in $packages; do
  echo -e "${BLUE}🔄 Checking $package for updates...${NC}"

  # Create a temporary branch for this package
  branch_name="update/$package"
  git checkout -b "$branch_name" 2>/dev/null || git checkout "$branch_name"
  git reset --hard origin/main

  # Try to update the package
  if output=$(nix-update "$package" --build --commit -vr ".*([0-9]+\.[0-9]+\.[0-9]+).*" 2>&1); then
    # Check if there was actually an update by looking for version info in output
    if echo "$output" | grep -q "Update.*->.*in" && ! echo "$output" | grep -q "No changes detected"; then
      # Extract version information
      version_info=$(echo "$output" | grep "Update.*->.*in" | head -1 | sed 's/.*Update \(.*\) in.*/\1/')
      log_success "Successfully updated $package ($version_info)"
      successful_updates+=("$package:$version_info:$branch_name")

      # Force push the branch
      git push origin "$branch_name" --force

      # Check if PR already exists, create if not
      log_info "Checking/creating PR for $package..."
      if gh pr view "$branch_name" --json state --jq '.state' 2>/dev/null | grep -q "OPEN"; then
        log_info "PR already exists for $package - updating title and description"
        gh pr edit "$branch_name" \
          --title "$package $version_info" \
          --body "Automated update of $package ($version_info)" || log_warning "Failed to update PR for $package"
      else
        # PR doesn't exist or is closed, create a new one
        gh pr create \
          --title "$package $version_info" \
          --body "Automated update of $package ($version_info)" \
          --head "$branch_name" \
          --base "main" || log_warning "Failed to create PR for $package"
      fi
    else
      # No changes detected - handle cleanup
      log_warning "$package is already up to date"
      skipped_updates+=("$package")
      if gh pr view "$branch_name" --json state --jq '.state' 2>/dev/null | grep -q "OPEN"; then
        log_info "Closing PR for $package (already up to date)"
        gh pr close "$branch_name" --comment "Package is already up to date" || log_warning "Failed to close PR for $package"
        git push origin --delete "$branch_name" 2>/dev/null || true
      fi
    fi
  else
    exit_code=$?
    if [ $exit_code -eq 2 ] || echo "$output" | grep -q "No changes detected"; then
      log_warning "$package is already up to date"
      skipped_updates+=("$package")
    elif echo "$output" | grep -q "Could not find a url in the derivations src attribute"; then
      log_warning "$package: Cannot update (no URL in src - likely local source)"
      skipped_updates+=("$package")
    else
      log_error "Failed to update $package (exit code: $exit_code)"
      echo "$output" | head -5
      failed_updates+=("$package")
    fi
    git checkout main
    git branch -D "$branch_name" 2>/dev/null || true
  fi

  # Switch back to main for next package
  git checkout main
  echo
done

# Summary
echo "========================================="
echo -e "${BLUE}📊 Update Summary${NC}"
echo "========================================="

if [ ${#successful_updates[@]} -gt 0 ]; then
  log_success "Successfully updated (${#successful_updates[@]}):"
  for package_info in "${successful_updates[@]}"; do
    package=$(echo "$package_info" | cut -d: -f1)
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
  echo -e "${GREEN}🎉 Created/Updated ${#successful_updates[@]} PRs for package updates!${NC}"
else
  echo -e "${BLUE}✨ All packages are already up to date!${NC}"
fi
