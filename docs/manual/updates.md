# Automated Package Updates {#ch-automated-updates}

Package updates are handled by `scripts/update.py`, which wraps
[`nix-update`](https://github.com/Mic92/nix-update).

## When it runs {#sec-updates-when}

- **Daily** at 6 AM Berlin time via GitHub Actions (macOS + Linux runners in
  parallel)
- **On every PR** (dry-run, no commit — only checks packages changed in the PR)
- **Manually** via the GitHub Actions interface or locally:

```bash
nix develop
python3 scripts/update.py                       # all packages
python3 scripts/update.py -p opsops -p ndcli    # single or multiple packages
python3 scripts/update.py --dry-run             # check without committing
```

## Enabling updates for a package {#sec-updates-enabling}

Add `nix-update-script` as a function argument and set `passthru.updateScript`:

```nix
{ lib, buildGoModule, fetchFromGitHub, nix-update-script }:
buildGoModule rec {
  pname = "my-package";
  version = "1.2.3";
  # ...
  passthru.updateScript = nix-update-script { };
}
```

The `--flake` flag is injected automatically for all packages via the `pkgs'`
override in `packages/default.nix` — no need to add it manually.

For packages needing custom update behaviour (e.g. tracking a branch, non-standard
tag format), pass extra arguments — see the
[nix-update documentation](https://github.com/Mic92/nix-update) for available options:

```nix
passthru.updateScript = nix-update-script { extraArgs = [ "--version=branch" ]; };
```

Packages without `passthru.updateScript` (e.g. local sources) are skipped
automatically.

## Platform routing {#sec-updates-platforms}

- **Cross-platform packages** are updated by the macOS runner only — avoids
  duplicate PRs
- **Linux-only packages** (`meta.platforms = lib.platforms.linux`) are updated
  by the Linux runner
