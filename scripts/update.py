#!/usr/bin/env python3
"""
Unified package update script for nixkit.
Automatically updates packages and optionally creates PRs in CI.
"""

import json
import os
import re
import subprocess
import sys
from dataclasses import dataclass
from enum import Enum
from typing import Optional


class Color:
    RED = "\033[0;31m"
    GREEN = "\033[0;32m"
    YELLOW = "\033[1;33m"
    BLUE = "\033[0;34m"
    NC = "\033[0m"


class UpdateStatus(Enum):
    SUCCESS = "success"
    SKIPPED = "skipped"
    FAILED = "failed"


@dataclass
class UpdateResult:
    package: str
    status: UpdateStatus
    version_info: Optional[str] = None
    error: Optional[str] = None


def log(level: str, message: str):
    colors = {
        "info": (Color.BLUE, "🔍"),
        "success": (Color.GREEN, "✅"),
        "warning": (Color.YELLOW, "⚠️"),
        "error": (Color.RED, "❌"),
    }
    color, emoji = colors.get(level, (Color.NC, ""))
    print(f"{color}{emoji} {message}{Color.NC}", flush=True)


def run_command(
    cmd: list[str], timeout: int = 600, capture: bool = True, json_output: bool = False
) -> tuple[int, str]:
    """Run a command and return (exit_code, output)"""
    try:
        if capture:
            result = subprocess.run(
                cmd, capture_output=True, text=True, timeout=timeout, check=False
            )
            # For JSON output, only return stdout to avoid parsing warnings
            output = result.stdout if json_output else result.stdout + result.stderr
            return result.returncode, output
        else:
            result = subprocess.run(cmd, timeout=timeout, check=False)
            return result.returncode, ""
    except subprocess.TimeoutExpired:
        return 124, "Command timed out"
    except Exception as e:
        return 1, str(e)


def get_current_system() -> str:
    """Get the current Nix system"""
    exit_code, system = run_command(
        ["nix", "eval", "--impure", "--raw", "--expr", "builtins.currentSystem"]
    )
    if exit_code != 0:
        log("error", "Failed to determine system")
        sys.exit(1)
    return system.strip()


def get_packages() -> list[str]:
    """Get all packages from the flake"""
    log("info", "Discovering packages...")

    system = get_current_system()

    # Get packages - use json_output=True to avoid warnings in output
    exit_code, output = run_command(
        [
            "nix",
            "eval",
            "--json",
            f".#packages.{system}",
            "--apply",
            "builtins.attrNames",
        ],
        json_output=True,
    )

    if exit_code != 0:
        log("error", "Failed to get packages from flake")
        sys.exit(1)

    packages = json.loads(output)
    log("info", f"Found packages: {' '.join(packages)}")
    return packages


def update_package(package: str, create_pr: bool = False) -> UpdateResult:
    """Update a single package"""
    log("info", f"Checking {package} for updates...")

    # If creating PR, manage git branches
    branch_name = f"update/{package}"
    if create_pr:
        # Ensure on main
        run_command(["git", "checkout", "main", "-q"], capture=True)
        # Delete old branch if exists
        run_command(["git", "branch", "-D", branch_name], capture=True)
        # Create new branch
        git_exit_code, _ = run_command(
            ["git", "checkout", "-b", branch_name, "-q"], capture=True
        )
        if git_exit_code != 0:
            return UpdateResult(
                package, UpdateStatus.FAILED, error="Failed to create branch"
            )

    # Try normal version update first (works for most packages)
    cmd = [
        "nix-update",
        package,
        "--flake",
        "--build",
        "--commit",
        "--version-regex",
        r".*?(\d+\.\d+\.\d+)$",
    ]

    update_exit_code, output = run_command(cmd, timeout=600)

    # If it fails with version error and mentions GitHub, try branch mode
    if update_exit_code != 0 and "Please specify the version" in output:
        log("info", f"{package} appears to be unstable, trying branch mode...")

        # Get homepage for --url flag
        system = get_current_system()
        homepage_exit_code, homepage = run_command(
            ["nix", "eval", "--raw", f".#packages.{system}.{package}.meta.homepage"]
        )

        if homepage_exit_code == 0 and homepage.strip():
            cmd = [
                "nix-update",
                package,
                "--flake",
                "--build",
                "--commit",
                "--version=branch",
                "--url",
                homepage.strip(),
            ]
            update_exit_code, output = run_command(cmd, timeout=600)
        else:
            # No homepage, can't use branch mode
            pass

    # Parse result
    if update_exit_code == 0:
        # Check for actual update
        if (
            "Update" in output
            and "->" in output
            and "No changes detected" not in output
        ):
            # Extract version info
            match = re.search(r"Update (.*?) in", output)
            version_info = match.group(1) if match else "unknown"

            if create_pr:
                # Check if there are actual changes to push
                diff_exit_code, _ = run_command(
                    ["git", "diff", "--quiet", "HEAD"], capture=True
                )

                if diff_exit_code != 0:
                    # There are changes, push them
                    push_code, _ = run_command(
                        ["git", "push", "origin", branch_name, "--force"], capture=False
                    )
                    if push_code == 0:
                        handle_pr(package, branch_name, version_info)
                else:
                    # No changes, but PR might need updating
                    handle_pr(package, branch_name, version_info)

            return UpdateResult(
                package, UpdateStatus.SUCCESS, version_info=version_info
            )
        else:
            # No update needed
            if create_pr:
                cleanup_branch(package, branch_name, up_to_date=True)
            return UpdateResult(
                package, UpdateStatus.SKIPPED, error="Already up to date"
            )

    # Handle errors
    if update_exit_code == 124:
        error = "Timeout after 10 minutes"
    elif update_exit_code == 2 or "No changes detected" in output:
        if create_pr:
            cleanup_branch(package, branch_name, up_to_date=True)
        return UpdateResult(package, UpdateStatus.SKIPPED, error="Already up to date")
    elif "Could not find a url in the derivations src attribute" in output:
        if create_pr:
            cleanup_branch(package, branch_name, up_to_date=True)
        return UpdateResult(
            package, UpdateStatus.SKIPPED, error="No URL in src (local source)"
        )
    elif "error" in output.lower() and "eval" in output.lower():
        error = "Nix evaluation error (complex versioning/dependencies)"
    else:
        # Get first few lines of error
        error_lines = output.split("\n")[:3]
        error = "\n".join(error_lines)

    if create_pr:
        cleanup_branch(package, branch_name, up_to_date=False)

    return UpdateResult(package, UpdateStatus.FAILED, error=error)


def handle_pr(package: str, branch: str, version_info: str):
    """Create or update PR for package update"""
    # Check PR state
    pr_check_exit_code, pr_state = run_command(
        ["gh", "pr", "view", branch, "--json", "state", "--jq", ".state"]
    )

    pr_state = pr_state.strip() if pr_check_exit_code == 0 else "NOT_FOUND"

    title = f"chore(deps): update {package} to {version_info}"
    body = f"Automated update of {package} to {version_info}"

    if pr_state == "OPEN":
        log("info", f"Updating existing PR for {package}")
        run_command(
            ["gh", "pr", "edit", branch, "--title", title, "--body", body],
            capture=False,
        )
    elif pr_state == "NOT_FOUND":
        log("info", f"Creating PR for {package}")
        run_command(
            [
                "gh",
                "pr",
                "create",
                "--title",
                title,
                "--body",
                body,
                "--head",
                branch,
                "--base",
                "main",
            ],
            capture=False,
        )


def cleanup_branch(package: str, branch: str, up_to_date: bool):
    """Clean up branch and PR if no update needed"""
    run_command(["git", "checkout", "main", "-q"], capture=True)
    run_command(["git", "branch", "-D", branch], capture=True)

    if up_to_date:
        # Close PR if it exists
        pr_check_exit_code, pr_state = run_command(
            ["gh", "pr", "view", branch, "--json", "state", "--jq", ".state"]
        )

        if pr_check_exit_code == 0 and pr_state.strip() == "OPEN":
            log("info", f"Closing obsolete PR for {package}")
            run_command(
                [
                    "gh",
                    "pr",
                    "close",
                    branch,
                    "--comment",
                    "Package is already up to date",
                    "--delete-branch",
                ],
                capture=True,
            )


def print_summary(results: list[UpdateResult]):
    """Print update summary"""
    print("\n" + "=" * 40, flush=True)
    print(f"{Color.BLUE}📊 Update Summary{Color.NC}", flush=True)
    print("=" * 40 + "\n", flush=True)

    successful = [r for r in results if r.status == UpdateStatus.SUCCESS]
    skipped = [r for r in results if r.status == UpdateStatus.SKIPPED]
    failed = [r for r in results if r.status == UpdateStatus.FAILED]

    if successful:
        log("success", f"Successfully updated ({len(successful)}):")
        for result in successful:
            print(
                f"  ✅ {result.package}"
                + (f" ({result.version_info})" if result.version_info else "")
            )
        print()

    if skipped:
        log("warning", f"Skipped ({len(skipped)}):")
        for result in skipped:
            reason = f" - {result.error}" if result.error else ""
            print(f"  ⏭️  {result.package}{reason}")
        print()

    if failed:
        log("error", f"Failed ({len(failed)}):")
        for result in failed:
            print(f"  ❌ {result.package}")
            if result.error:
                print(f"     {result.error}")
        print()
        return 1

    if successful:
        print(f"{Color.GREEN}🎉 All updates completed successfully!{Color.NC}")
        if not os.getenv("CI"):
            print(f"{Color.BLUE}💡 Don't forget to push: git push{Color.NC}")
    else:
        print(f"{Color.BLUE}✨ All packages are up to date!{Color.NC}")

    return 0


def main():
    # Check if in git repo
    git_check_exit_code, _ = run_command(["git", "rev-parse", "--git-dir"])
    if git_check_exit_code != 0:
        log("error", "Not in a git repository!")
        sys.exit(1)

    # Determine if we're in CI (should create PRs)
    create_prs = bool(os.getenv("CI"))

    if not create_prs:
        # Check for uncommitted changes
        git_status_exit_code, _ = run_command(
            ["git", "diff-index", "--quiet", "HEAD", "--"]
        )
        if git_status_exit_code != 0:
            log("warning", "Working directory has uncommitted changes.")
            response = input("Continue anyway? (y/N): ").strip().lower()
            if response != "y":
                log("info", "Aborted by user.")
                sys.exit(0)

    # Get packages
    packages = get_packages()
    print()

    results = []
    for package in packages:
        result = update_package(package, create_pr=create_prs)

        # Log result
        if result.status == UpdateStatus.SUCCESS:
            log(
                "success",
                f"Successfully updated {package}"
                + (f" ({result.version_info})" if result.version_info else ""),
            )
        elif result.status == UpdateStatus.SKIPPED:
            log("warning", f"{package}: {result.error}")
        else:
            log("error", f"Failed to update {package}")
            if result.error:
                print(result.error)

        results.append(result)

        # Ensure we're back on main after each package
        if create_prs:
            run_command(["git", "checkout", "main", "-q"], capture=True)
        print()

    # Print summary and exit
    exit_code = print_summary(results)
    sys.exit(exit_code)


if __name__ == "__main__":
    main()
