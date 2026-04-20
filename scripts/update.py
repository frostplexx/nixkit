#!/usr/bin/env python3
"""
Unified package update script for nixkit.
Automatically updates packages and optionally creates PRs in CI.
"""

import argparse
import os
import re
import shutil
import subprocess
import sys
import tempfile
from dataclasses import dataclass
from enum import Enum
from typing import Optional


class Color:  # pylint: disable=too-few-public-methods
    """ANSI color codes for terminal output."""

    RED = "\033[0;31m"
    GREEN = "\033[0;32m"
    YELLOW = "\033[1;33m"
    BLUE = "\033[0;34m"
    NC = "\033[0m"


class UpdateStatus(Enum):
    """Possible outcomes of a package update attempt."""

    SUCCESS = "success"
    UP_TO_DATE = "up_to_date"
    SKIPPED = "skipped"
    FAILED = "failed"


@dataclass
class UpdateResult:
    """Result of a single package update attempt."""

    package: str
    status: UpdateStatus
    version_info: Optional[str] = None
    error: Optional[str] = None


def log(level: str, message: str):
    """Print a colored, emoji-prefixed log line."""
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
    cwd: Optional[str] = None,
) -> tuple[int, str]:
    """Run a subprocess and return (exit_code, output)."""
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
            output = result.stdout + result.stderr
            return result.returncode, output
        result = subprocess.run(cmd, timeout=timeout, check=False, cwd=cwd)
        return result.returncode, ""
    except subprocess.TimeoutExpired:
        return 124, "Command timed out"
    except Exception as e:  # pylint: disable=broad-exception-caught
        return 1, str(e)


def get_current_system() -> str:
    """Return the current Nix system string (e.g. aarch64-darwin)."""
    exit_code, system = run_command(
        ["nix", "eval", "--impure", "--raw", "--expr", "builtins.currentSystem"]
    )
    if exit_code != 0:
        log("error", "Failed to determine system")
        sys.exit(1)
    return system.strip()


def get_packages() -> dict[str, dict]:
    """Discover packages by scanning packages/*/default.nix files.

    Skips packages without 'passthru.updateScript'.
    Returns {name: {linux_only: bool}}.
    """
    log("info", "Discovering packages...")
    packages = {}
    for name in sorted(os.listdir("packages")):
        path = os.path.join("packages", name, "default.nix")
        if not os.path.isfile(path):
            continue
        with open(path, encoding="utf-8") as f:
            content = f.read()
        if "passthru.updateScript" not in content:
            continue
        linux_only = bool(
            re.search(r"platforms\.linux", content)
            and not re.search(r"platforms\.(darwin|unix)", content)
        )
        packages[name] = {"linux_only": linux_only}
    log("info", f"Found packages: {' '.join(packages.keys())}")
    return packages


def _read_version(package: str, cwd: Optional[str] = None) -> str:
    """Read version from packages/{package}/default.nix (last match = main derivation)."""
    try:
        path = os.path.join(cwd or ".", "packages", package, "default.nix")
        with open(path, encoding="utf-8") as f:
            content = f.read()
        matches = re.findall(r'^\s*version\s*=\s*"([^"]+)"', content, re.MULTILINE)
        return matches[-1] if matches else ""
    except FileNotFoundError:
        return ""


def update_package(  # pylint: disable=too-many-branches,too-many-statements,too-many-locals,too-many-return-statements
    package: str,
    info: dict,
    system: str,
    create_pr: bool = False,
    dry_run: bool = False,
) -> UpdateResult:
    """Run nix-update for a single package and return the result."""
    log("info", f"Checking {package}..." + (" (dry run)" if dry_run else ""))

    # On Linux: only update packages that are explicitly Linux-only.
    # Cross-platform packages are handled by the macOS runner to avoid double-updates.
    if "linux" in system and not info["linux_only"]:
        return UpdateResult(
            package,
            UpdateStatus.SKIPPED,
            error="Cross-platform — updated by macOS runner",
        )

    # In dry-run mode, copy the repo to a temp dir so nix-update never
    # touches the real working tree.
    run_cwd = None
    tmp_copy = None
    if dry_run:
        tmp_copy = tempfile.mkdtemp(prefix="nixkit-dryrun-")
        shutil.copytree(".", tmp_copy, symlinks=True, dirs_exist_ok=True)
        run_cwd = tmp_copy

    try:
        branch_name = f"update/{package}"
        if create_pr:
            run_command(["git", "checkout", "main", "-q"])
            run_command(["git", "branch", "-D", branch_name])
            exit_code, _ = run_command(["git", "checkout", "-b", branch_name, "-q"])
            if exit_code != 0:
                return UpdateResult(
                    package, UpdateStatus.FAILED, error="Failed to create branch"
                )

        # Snapshot HEAD before so we can detect if nix-update committed.
        _, head_before = run_command(["git", "rev-parse", "HEAD"])

        cmd = ["nix-update", "--flake", "--use-update-script", "--build"]
        if not dry_run:
            cmd.append("--commit")
        cmd.append(package)

        ver_before = _read_version(package, cwd=run_cwd)
        update_exit_code, output = run_command(cmd, timeout=600, cwd=run_cwd)

        if update_exit_code == 124:
            if create_pr:
                cleanup_branch(package, branch_name, up_to_date=False)
            return UpdateResult(package, UpdateStatus.FAILED, error="Timeout")

        if update_exit_code not in (0, 2):
            if create_pr:
                cleanup_branch(package, branch_name, up_to_date=False)
            return UpdateResult(package, UpdateStatus.FAILED, error=output.strip())

        # Detect whether an update actually happened via git state, not output parsing:
        # dry-run: changes land in tmp_copy — check its working tree
        # normal:  nix-update commits on success — HEAD will have moved
        if dry_run:
            diff_code, _ = run_command(["git", "diff", "--quiet"], cwd=run_cwd)
            was_updated = diff_code != 0
        else:
            _, head_after = run_command(["git", "rev-parse", "HEAD"])
            was_updated = head_before.strip() != head_after.strip()

        if was_updated:
            ver_after = _read_version(package, cwd=run_cwd)
            version_info = (
                f"{ver_before} -> {ver_after}"
                if ver_before and ver_after
                else "unknown"
            )

            if create_pr:
                diff_exit_code, _ = run_command(
                    ["git", "diff", "--quiet", "main..HEAD"]
                )
                if diff_exit_code != 0:
                    push_code, _ = run_command(
                        ["git", "push", "origin", branch_name, "--force"],
                        capture=False,
                    )
                    if push_code == 0:
                        handle_pr(package, branch_name, version_info)
                else:
                    handle_pr(package, branch_name, version_info)

            return UpdateResult(
                package, UpdateStatus.SUCCESS, version_info=version_info
            )

        if create_pr:
            cleanup_branch(package, branch_name, up_to_date=True)
        return UpdateResult(package, UpdateStatus.UP_TO_DATE)
    finally:
        if tmp_copy:
            shutil.rmtree(tmp_copy, ignore_errors=True)


def handle_pr(package: str, branch: str, version_info: str):
    """Create or update the GitHub PR for a package update branch."""
    exit_code, pr_state = run_command(
        ["gh", "pr", "view", branch, "--json", "state", "--jq", ".state"]
    )
    pr_state = pr_state.strip() if exit_code == 0 else "NOT_FOUND"

    title = f"chore(deps): update {package} to {version_info}"
    body = f"Automated update of {package} to {version_info}"

    if pr_state == "OPEN":
        log("info", f"Updating existing PR for {package}")
        run_command(
            ["gh", "pr", "edit", branch, "--title", title, "--body", body],
            capture=False,
        )
    else:
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
    """Delete the update branch and close its PR if the package is already current."""
    run_command(["git", "checkout", "main", "-q"])
    run_command(["git", "branch", "-D", branch])

    if up_to_date:
        exit_code, pr_state = run_command(
            ["gh", "pr", "view", branch, "--json", "state", "--jq", ".state"]
        )
        if exit_code == 0 and pr_state.strip() == "OPEN":
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
            )


def print_summary(results: list[UpdateResult], dry_run: bool = False) -> int:
    """Print a grouped summary and return 1 if any package failed."""
    print("\n" + "=" * 40, flush=True)
    print(f"{Color.BLUE}📊 Update Summary{Color.NC}", flush=True)
    print("=" * 40 + "\n", flush=True)

    successful = [r for r in results if r.status == UpdateStatus.SUCCESS]
    up_to_date = [r for r in results if r.status == UpdateStatus.UP_TO_DATE]
    skipped = [r for r in results if r.status == UpdateStatus.SKIPPED]
    failed = [r for r in results if r.status == UpdateStatus.FAILED]

    if successful:
        log("success", f"Successfully updated ({len(successful)}):")
        for r in successful:
            print(
                f"  ✅ {r.package}" + (f" ({r.version_info})" if r.version_info else "")
            )
        print()

    if up_to_date:
        log("success", f"Already up to date ({len(up_to_date)}):")
        for r in up_to_date:
            print(f"  ✅ {r.package}")
        print()

    if skipped:
        log("warning", f"Skipped ({len(skipped)}):")
        for r in skipped:
            print(f"  ⏭️  {r.package}" + (f" - {r.error}" if r.error else ""))
        print()

    if failed:
        log("error", f"Failed ({len(failed)}):")
        for r in failed:
            print(f"  ❌ {r.package}")
            if r.error:
                print(f"     {r.error}")
        print()
        return 1

    if successful:
        print(f"{Color.GREEN}🎉 All updates completed successfully!{Color.NC}")
        if not os.getenv("CI") and not dry_run:
            print(f"{Color.BLUE}💡 Don't forget to push: git push{Color.NC}")
    elif up_to_date:
        print(f"{Color.BLUE}✨ All packages are up to date!{Color.NC}")
    else:
        print(f"{Color.BLUE}✨ No updates applied.{Color.NC}")
    return 0


def main():  # pylint: disable=too-many-branches
    """Entry point: parse args, discover packages, run updates."""
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
        help="Check for updates and build without committing",
    )
    args = parser.parse_args()

    if run_command(["git", "rev-parse", "--git-dir"])[0] != 0:
        log("error", "Not in a git repository!")
        sys.exit(1)

    create_prs = bool(os.getenv("CI")) and not args.dry_run

    if not create_prs and not args.dry_run:
        if run_command(["git", "diff-index", "--quiet", "HEAD", "--"])[0] != 0:
            log("warning", "Working directory has uncommitted changes.")
            if input("Continue anyway? (y/N): ").strip().lower() != "y":
                sys.exit(0)

    system = get_current_system()
    all_packages = get_packages()

    if args.packages:
        unknown = set(args.packages) - set(all_packages.keys())
        if unknown:
            log("error", f"Unknown package(s): {' '.join(sorted(unknown))}")
            sys.exit(1)
        packages = {k: all_packages[k] for k in args.packages}
    else:
        packages = all_packages
    print()

    results = []
    for package, info in packages.items():
        result = update_package(
            package, info, system, create_pr=create_prs, dry_run=args.dry_run
        )

        if result.status == UpdateStatus.SUCCESS:
            log(
                "success",
                f"Updated {package}"
                + (f" ({result.version_info})" if result.version_info else ""),
            )
        elif result.status == UpdateStatus.UP_TO_DATE:
            log("success", f"{package}: already up to date")
        elif result.status == UpdateStatus.SKIPPED:
            log("warning", f"{package}: {result.error}")
        else:
            log("error", f"Failed to update {package}")
            if result.error:
                print(result.error)

        results.append(result)
        if create_prs:
            run_command(["git", "checkout", "main", "-q"])
        print()

    sys.exit(print_summary(results, dry_run=args.dry_run))


if __name__ == "__main__":
    main()
