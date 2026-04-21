"""PR and branch handling for the package update script."""

import subprocess
from typing import Optional


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


def log(level: str, message: str):
    """Print a colored, emoji-prefixed log line."""
    colors = {
        "info": ("\033[0;34m", "🔍"),
        "success": ("\033[0;32m", "✅"),
        "warning": ("\033[1;33m", "⚠️"),
        "error": ("\033[0;31m", "❌"),
    }
    color, emoji = colors.get(level, ("\033[0m", ""))
    print(f"{color}{emoji} {message}\033[0m", flush=True)


def branch_name_for(package: str) -> str:
    """Return the conventional update branch name for a package."""
    return f"update/{package}"


def prepare_branch(package: str) -> tuple[bool, str]:
    """Check out main and create a fresh update branch for the package.

    Returns (success, branch_name).
    """
    branch = branch_name_for(package)
    run_command(["git", "checkout", "main", "-q"])
    run_command(["git", "branch", "-D", branch])
    exit_code, _ = run_command(["git", "checkout", "-b", branch, "-q"])
    return exit_code == 0, branch


def push_branch(branch: str) -> bool:
    """Force-push the update branch to origin."""
    push_code, _ = run_command(
        ["git", "push", "origin", branch, "--force"],
        capture=False,
    )
    return push_code == 0


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


def publish_update(package: str, branch: str, version_info: str):
    """Push the branch if it has commits beyond main, then open/update the PR."""
    diff_exit_code, _ = run_command(["git", "diff", "--quiet", "main..HEAD"])
    if diff_exit_code != 0:
        if push_branch(branch):
            handle_pr(package, branch, version_info)
    else:
        handle_pr(package, branch, version_info)
