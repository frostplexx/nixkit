#!/usr/bin/env python3
"""
Unified package update script for nixkit.
Automatically updates packages and optionally creates PRs in CI.
"""

import argparse
import json
import os
import re
import shutil
import subprocess
import sys
import tempfile
from dataclasses import dataclass
from enum import Enum
from typing import Optional

EXCLUDED_PACKAGES = ["manpages", "manualHTML", "optionsJSON", "website"]


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
    cmd: list[str],
    timeout: int = 600,
    capture: bool = True,
    json_output: bool = False,
    cwd: Optional[str] = None,
) -> tuple[int, str]:
    """Run a command and return (exit_code, output)"""
    try:
        if capture:
            result = subprocess.run(
                cmd,
                capture_output=True,
                text=True,
                timeout=timeout,
                check=False,
                cwd=cwd,
            )
            # For JSON output, only return stdout to avoid parsing warnings
            output = result.stdout if json_output else result.stdout + result.stderr
            return result.returncode, output
        else:
            result = subprocess.run(cmd, timeout=timeout, check=False, cwd=cwd)
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


def update_package(
    package: str, create_pr: bool = False, dry_run: bool = False
) -> UpdateResult:
    """Update a single package"""
    if package in EXCLUDED_PACKAGES:
        return UpdateResult(
            package, UpdateStatus.SKIPPED, error="Excluded (generated package)"
        )

    log(
        "info", f"Checking {package} for updates..." + (" (dry run)" if dry_run else "")
    )

    # In dry-run mode, copy the repo to a temp directory so nix-update runs
    # on an exact snapshot of the current working tree (including uncommitted
    # changes) without touching anything in the real repo.
    run_cwd = None
    tmp_copy = None
    if dry_run:
        tmp_copy = tempfile.mkdtemp(prefix="nixkit-dryrun-")
        shutil.copytree(".", tmp_copy, symlinks=True, dirs_exist_ok=True)
        run_cwd = tmp_copy

    try:
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
            "--version-regex",
            r".*?(\d+\.\d+\.\d+)$",
        ]
        if not dry_run:
            cmd.append("--commit")

        update_exit_code, output = run_command(cmd, timeout=600, cwd=run_cwd)

        # If it fails with version error and mentions GitHub, try branch mode
        if update_exit_code != 0 and "Please specify the version" in output:
            log("info", f"{package} appears to be unstable, trying branch mode...")

            # Get homepage for --url flag
            system = get_current_system()
            homepage_exit_code, homepage = run_command(
                [
                    "nix",
                    "eval",
                    "--raw",
                    f".#packages.{system}.{package}.meta.homepage",
                ],
                json_output=True,  # stdout only — avoids nix warnings in stderr corrupting the URL
            )

            if homepage_exit_code == 0 and homepage.strip():
                cmd = [
                    "nix-update",
                    package,
                    "--flake",
                    "--build",
                    "--version=branch",
                    "--url",
                    homepage.strip(),
                ]
                if not dry_run:
                    cmd.append("--commit")
                update_exit_code, output = run_command(cmd, timeout=600, cwd=run_cwd)

    finally:
        if tmp_copy:
            shutil.rmtree(tmp_copy, ignore_errors=True)

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
                # Check if there are new commits compared to main
                diff_exit_code, _ = run_command(
                    ["git", "diff", "--quiet", "main..HEAD"], capture=True
                )

                if diff_exit_code != 0:
                    # There are new commits, push them
                    push_code, _ = run_command(
                        ["git", "push", "origin", branch_name, "--force"], capture=False
                    )
                    if push_code == 0:
                        handle_pr(package, branch_name, version_info)
                else:
                    # No new commits, but PR might need updating
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
    elif "expected a set but found null" in output:
        if create_pr:
            cleanup_branch(package, branch_name, up_to_date=True)
        return UpdateResult(
            package,
            UpdateStatus.SKIPPED,
            error="No version attribute (generated/doc package)",
        )
    elif "hash mismatch" in output:
        error = "Hash mismatch for rev, update hash manually"
    elif "error" in output.lower() and "eval" in output.lower():
        error = "Nix evaluation error (complex versioning/dependencies)"
    else:
        error = output.strip()

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
    else:
        # Create new PR for NOT_FOUND, MERGED, or CLOSED states
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
    parser = argparse.ArgumentParser(description="Update nixkit packages")
    parser.add_argument(
        "-p",
        "--package",
        metavar="PKG",
        action="append",
        dest="packages",
        help="Only update this package (can be specified multiple times)",
    )
    parser.add_argument(
        "-d",
        "--dry-run",
        action="store_true",
        dest="dry_run",
        help="Check for updates and build in an isolated worktree, without modifying the working tree",
    )
    args = parser.parse_args()

    # Check if in git repo
    git_check_exit_code, _ = run_command(["git", "rev-parse", "--git-dir"])
    if git_check_exit_code != 0:
        log("error", "Not in a git repository!")
        sys.exit(1)

    # Determine if we're in CI (should create PRs)
    create_prs = bool(os.getenv("CI")) and not args.dry_run

    if not create_prs and not args.dry_run:
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

    # Get packages (filtered if -p was given)
    all_packages = get_packages()
    if args.packages:
        unknown = set(args.packages) - set(all_packages)
        if unknown:
            log("error", f"Unknown package(s): {' '.join(sorted(unknown))}")
            sys.exit(1)
        packages = args.packages
    else:
        packages = all_packages
    print()

    results = []
    for package in packages:
        result = update_package(package, create_pr=create_prs, dry_run=args.dry_run)

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
