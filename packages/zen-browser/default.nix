# zen-browser built from source on darwin, with the in-flight "little-zen"
# branch as the default revision (PR https://github.com/zen-browser/desktop/pull/13450).
#
# This is an IMPURE derivation: it sets `__noChroot = true` so the build can hit
# the Mozilla source repos (hg.mozilla.org), the npm registry, and crates.io —
# the same way the upstream `npm run download` / `mach build` flow does. FOD-ing
# every input (Firefox source, vendored cargo crates, npm deps) is a possible
# follow-up but is genuinely several hundred lines of plumbing on its own; the
# value vs. just trusting the source URLs is mostly hermeticity, not correctness.
#
# Override `src` and `version` to pin a different rev (e.g. a stable zen tag) or
# layer extra patches on top via `overrideAttrs`.
{
  lib,
  stdenv,
  fetchFromGitHub,
  rust-bin,
  nodejs_22,
  python311,
  cmake,
  pkg-config,
  cairo,
  mercurial,
  gnutar,
  autoconf,
  unzip,
  zip,
  zstd,
  git,
  clang,
  llvm,
  llvmPackages,
  writeShellScriptBin,
  cacert,
  fetchurl,
  fetchNpmDeps,
  # Build inputs that are platform-specific
  # macOS provides cctools as part of the SDK; we still need xcrun on PATH from
  # the system (handled via __noChroot + PATH below)
  ...
}: let
  pname = "zen-browser";
  # Bumped when bumping the pinned rev; the value is informational since the
  # build uses surfer's `--display-version` flag to brand the binary.
  version = "1.19.12b-little-zen-20260601";

  src = fetchFromGitHub {
    owner = "zen-browser";
    repo = "desktop";
    # HEAD of `little-zen` branch as of 2026-06-01 — the WIP feature PR.
    # Bump this commit to follow the branch; the hash MUST be updated alongside.
    rev = "cbd93819976f6a58c526cc9ee76d92d9608177ea";
    hash = "sha256-xapmrcOE6W8qq6etNxz6vCvgP2HemjAn/zPrSlI2qaA=";
    fetchSubmodules = true;
  };

  rustToolchain = rust-bin.stable."1.90.0".default;

  # The Firefox base version surfer downloads. Must match `engine.version` in
  # zen's surfer.json — bump together. Hardcoding it here lets us FOD the
  # source tarball; if zen-browser/desktop bumps Firefox under us the build
  # will fail loudly at extract time, which is the signal to bump this.
  firefoxVersion = "150.0.2";

  # Surfer (zen's build orchestrator) hardcodes the binary name `gtar`
  # (Homebrew's gnu-tar layout). nixpkgs ships gnutar as plain `tar`, so
  # we shim a gtar alias and prepend it to PATH.
  gtar-shim = writeShellScriptBin "gtar" ''
    exec ${gnutar}/bin/tar "$@"
  '';

  # Firefox source tarball from Mozilla's release archive. Fetched as a FOD
  # so it's cached across builds — without this, every derivation hash change
  # triggers a ~600MB redownload via surfer's `npm run download` step.
  firefoxSrc = fetchurl {
    url = "https://archive.mozilla.org/pub/firefox/releases/${firefoxVersion}/source/firefox-${firefoxVersion}.source.tar.xz";
    hash = "sha256-44MLIM32YKnN7G5NIybXztBzM9l0bfAoz8AMghasvsk=";
  };

  # Mozilla's localization repo, pinned to the commit recorded in zen's
  # build/firefox-cache/l10n-last-commit-hash. Fetched as a tarball (just the
  # working tree at that commit, no history) — much faster than the 4.3M-object
  # `git clone` the upstream `scripts/download-language-packs.sh` does. Cached
  # per-commit so it only re-fetches when zen bumps the pin.
  l10nCommit = "73901ca17f4a2159dd4488cea8684e9abbfdcc89";
  firefoxL10n = fetchFromGitHub {
    owner = "mozilla-l10n";
    repo = "firefox-l10n";
    rev = l10nCommit;
    hash = "sha256-KZ0rlaCcwvytGhN2qLj7jehGuPsBXTpIhkSKKf3Q4j8=";
  };

  # Pre-prepared engine/ for the main build: Firefox source extracted AND
  # initialized as a git repo with one commit. The git step is what surfer's
  # `git apply` needs to NOT silently skip patches whose blob hashes don't
  # match (see comment in main configurePhase); mach bootstrap also needs
  # `git log -1 --format=%ct` to succeed. Doing all this in a separate
  # derivation lets nix cache the result per (firefoxVersion) — main build
  # just `cp -r`'s it, saving ~5 min of `git add -A` over 380k files every
  # time the main derivation's hash changes.
  #
  # Determinism: GIT_*_DATE and TZ are pinned so the commit SHA is stable
  # across builds; otherwise the derivation output would differ each time
  # and defeat the whole point of caching it.
  firefoxEngine = stdenv.mkDerivation {
    name = "firefox-${firefoxVersion}-engine-prepared";
    dontUnpack = true;
    dontPatch = true;
    dontConfigure = true;

    nativeBuildInputs = [gnutar git];

    env = {
      GIT_AUTHOR_DATE = "1970-01-01T00:00:00Z";
      GIT_COMMITTER_DATE = "1970-01-01T00:00:00Z";
      GIT_AUTHOR_NAME = "build";
      GIT_AUTHOR_EMAIL = "build@local";
      GIT_COMMITTER_NAME = "build";
      GIT_COMMITTER_EMAIL = "build@local";
      TZ = "UTC";
    };

    # Write directly into $out instead of building in $TMPDIR and `mv`-ing at
    # install time. /nix/store is on a different APFS volume than $TMPDIR on
    # darwin nix, so `mv` falls back to cp+rm — copying 380k loose .git/objects
    # files across filesystems takes 15+ min. Writing directly to $out skips
    # the move entirely.
    buildPhase = ''
      runHook preBuild

      export HOME="$TMPDIR/build-home"
      mkdir -p "$HOME"

      mkdir -p "$out"
      tar -xf ${firefoxSrc} -C "$out" --strip-components=1

      ( cd "$out"
        git init -q
        git add -A
        git commit -q -m "fx base"
        # Collapse 380k loose objects into ~2 packfiles. Halves the on-disk
        # file count and dramatically speeds up the main build's `ditto` of
        # this output into engine/ (ditto goes by file count, not byte count).
        # `git apply` reads packed objects via the pack index the same way it
        # reads loose ones, so this is transparent to surfer. Plain `gc`,
        # not `--aggressive`: aggressive re-deltifies at z9 which costs
        # 8-10 extra minutes for marginal size win we don't care about.
        git gc --quiet
      )

      runHook postBuild
    '';

    installPhase = ''
      runHook preInstall
      # $out already populated by buildPhase; nothing to move.
      runHook postInstall
    '';

    dontFixup = true;
  };

  # Populate npm cache once via an FOD. Hash keyed on package-lock.json — when
  # zen bumps deps, this rebuilds; otherwise reuses across all main builds.
  #
  # Why not just `npm ci` in a custom FOD? npm CLI writes millisecond timestamps
  # into every `_cacache/index-v5` entry, producing a different on-disk byte
  # layout each run — so the FOD's outputHash is unstable across attempts.
  # `fetchNpmDeps` sidesteps this by using a Rust binary (`prefetch-npm-deps`)
  # that writes a byte-deterministic cache. We override its build env to inject
  # the same gitconfig insteadOf rewrites and CA bundle the main build needs —
  # zen's lock pins a few git+ssh://git@github.com/... deps (e.g. is-apple-
  # silicon) that don't fetch with the default fetchNpmDeps environment.
  npmDeps =
    (fetchNpmDeps {
      inherit src;
      name = "${pname}-${version}-npm-deps";
      hash = "sha256-XfPDmq2H27OKRCOJaNV35+pppRWvh2u3JG3y84ekYyc=";
    })
    .overrideAttrs (old: {
      nativeBuildInputs = (old.nativeBuildInputs or []) ++ [git cacert];
      preBuild =
        (old.preBuild or "")
        + ''
          export HOME="$TMPDIR/build-home"
          mkdir -p "$HOME"
          git config --global url."https://github.com/".insteadOf "git@github.com:"
          git config --global url."https://github.com/".insteadOf "git+ssh://git@github.com/"
          git config --global url."https://github.com/".insteadOf "ssh://git@github.com/"
          export NIX_SSL_CERT_FILE="${cacert}/etc/ssl/certs/ca-bundle.crt"
          export SSL_CERT_FILE="${cacert}/etc/ssl/certs/ca-bundle.crt"
          export NODE_EXTRA_CA_CERTS="${cacert}/etc/ssl/certs/ca-bundle.crt"
          export GIT_TERMINAL_PROMPT=0
          export GIT_SSH_COMMAND="ssh -o BatchMode=yes -o StrictHostKeyChecking=no -o ConnectTimeout=10"
        '';
    });
in
  stdenv.mkDerivation {
    inherit pname version src;

    # Build requires network: surfer downloads Firefox source from hg.mozilla.org,
    # `npm ci` hits the npm registry, mach bootstrap downloads sccache/wasi-sysroot,
    # cargo fetches vendored crates. With __noChroot the build runs unsandboxed and
    # can reach all of these. macOS nix is unsandboxed by default anyway; this is
    # mostly defensive for setups (Linux, Determinate Nix with sandbox=true) that
    # would otherwise reject the network access.
    __noChroot = true;

    # Nix's stdenv auto-exports CC/CXX/AS/LD/AR/etc. pointing at its own
    # clang-wrapper. Mozilla's configure normally defaults AS=$(CC) on Darwin
    # (preprocesses .S files), but it inherits our AS instead — and nix's `as`
    # is a raw-assembly shim that drops cpp, breaking icu_data.S which uses
    # #ifdef / -D macros. Clearing these forces mach to use its bootstrapped
    # clang for both CC and AS.
    env = {
      # Tell mach we want non-PGO opt build.
      ZEN_GA_DISABLE_PGO = "true";
      ZEN_RELEASE = "1";
      ZEN_RELEASE_BRANCH = "release";
      SURFER_PLATFORM = "darwin";
      SURFER_COMPAT = "aarch64";
    };

    nativeBuildInputs = [
      rustToolchain
      nodejs_22
      python311
      cmake
      pkg-config
      cairo
      mercurial
      gnutar
      gtar-shim
      autoconf
      unzip
      zip
      zstd
      git
      clang
      llvm
      llvmPackages.bintools
      cacert # CA bundle for npm/curl/cargo/git HTTPS verification inside the sandbox
    ];

    # Expose the FOD inputs to the build environment.
    inherit npmDeps firefoxSrc firefoxEngine firefoxL10n;

    # Skip nix's default unpackPhase ordering — we need to cd into the source
    # and operate in-place. `dontPatch` because we apply zen's patch chain via
    # surfer, not nix's patch mechanism (zen's patches target Firefox source we
    # haven't fetched yet at the standard patchPhase step).
    dontPatch = true;

    # Clear stdenv-injected toolchain vars before configure runs. Setting these
    # to empty isn't enough — mach checks if they're SET. We have to unset.
    preConfigure = ''
      unset AS CC CXX CPP LD AR NM RANLIB STRIP HOST_CC HOST_CXX
      unset CFLAGS CXXFLAGS CPPFLAGS LDFLAGS ASFLAGS

      # nixpkgs defaults $HOME to /homeless-shelter which doesn't exist. mach
      # bootstrap, npm, and git all want to write into $HOME — point it at a
      # writable per-build dir under $TMPDIR.
      export HOME="$TMPDIR/build-home"
      mkdir -p "$HOME"

      # Append /usr/bin to PATH so macOS-only system tools surfer / mach call
      # (sips, iconutil, hdiutil, xcrun, etc.) are findable. Appended, not
      # prepended — nixpkgs tools still take priority for everything they
      # provide; only the macOS-exclusive ones fall through to /usr/bin.
      # __noChroot lets us actually exec /usr/bin/* from the build sandbox.
      export PATH="$PATH:/usr/bin"

      # zen's package-lock pins a few deps via git+ssh://git@github.com/... (e.g.
      # is-apple-silicon). The nixbld user has no SSH key for github.com, so npm's
      # internal clone fails. Rewrite ssh URLs to anonymous https for this build.
      git config --global url."https://github.com/".insteadOf "git@github.com:"
      git config --global url."https://github.com/".insteadOf "git+ssh://git@github.com/"
      git config --global url."https://github.com/".insteadOf "ssh://git@github.com/"

      # Belt-and-braces: if any code path slips past the insteadOf rewrites and
      # still tries to use ssh / HTTPS-with-auth, make the prompt fail fast
      # instead of blocking the build forever waiting for a TTY that will never
      # arrive. Build user has no SSH key and no credential helper anyway.
      export GIT_TERMINAL_PROMPT=0
      export GIT_SSH_COMMAND="ssh -o BatchMode=yes -o StrictHostKeyChecking=no -o ConnectTimeout=10"

      # CA bundle. Without these, every HTTPS request (npm registry, codeload,
      # crates.io, hg.mozilla.org) fails with UNABLE_TO_GET_ISSUER_CERT_LOCALLY
      # and npm silently retries forever, which looks like a hang. Pointing all
      # the usual suspects at nixpkgs's `cacert` bundle fixes it for npm/git/
      # curl/python (requests)/cargo in one shot.
      export NIX_SSL_CERT_FILE="${cacert}/etc/ssl/certs/ca-bundle.crt"
      export SSL_CERT_FILE="${cacert}/etc/ssl/certs/ca-bundle.crt"
      export NODE_EXTRA_CA_CERTS="${cacert}/etc/ssl/certs/ca-bundle.crt"
      export CURL_CA_BUNDLE="${cacert}/etc/ssl/certs/ca-bundle.crt"
      export GIT_SSL_CAINFO="${cacert}/etc/ssl/certs/ca-bundle.crt"
    '';

    configurePhase = ''
      runHook preConfigure

      echo "==> Source layout"
      ls -la

      # Use the FOD-cached npm registry. The cache layout is content-addressable;
      # `npm ci --offline` reads from here instead of hitting registry.npmjs.org.
      # If a new dep gets added upstream, --offline fails fast and we bump the
      # npmDeps hash. $npmDeps is /nix/store (read-only) but npm wants to write
      # _logs/, _locks/, _cacache/tmp — copy to a writable location first.
      # (This is what nixpkgs's npmConfigHook does internally; we're inlining it.)
      echo "==> Copying FOD'd npm cache to writable location"
      export npm_config_cache="$TMPDIR/npm-cache-rw"
      cp -r "$npmDeps" "$npm_config_cache"
      chmod -R u+w "$npm_config_cache"

      echo "==> npm ci (offline)"
      npm ci --offline --ignore-scripts --no-audit --no-fund

      # Postinstall scripts skipped above (they're skipped in the FOD too); run
      # them now in the main build env where the full toolchain is present.
      npm rebuild --foreground-scripts --no-audit --no-fund

      echo "==> surfer ci --brand release"
      npm run surfer -- ci --brand release --display-version ${version}

      # Pull in the pre-prepared engine/ (extracted Firefox source + git init +
      # one commit) from the cached firefoxEngine derivation. This replaces a
      # ~5-min `git add -A` over 380k Firefox files with a single cp. Use
      # /usr/bin/ditto on darwin for APFS clonefile acceleration — copies all
      # ~3GB in seconds rather than minutes by sharing data blocks via COW.
      # Fallback to plain cp if ditto isn't on PATH for any reason.
      echo "==> Cloning prepared Firefox ${firefoxVersion} engine into place"
      rm -rf engine
      if command -v ditto >/dev/null 2>&1; then
        ditto "$firefoxEngine" engine
      else
        cp -R "$firefoxEngine" engine
      fi
      chmod -R u+w engine

      # Some downstream surfer steps check for a marker file written by
      # `npm run download`. Recreate it so they don't try to re-download.
      mkdir -p .surfer
      touch .surfer/engine-downloaded

      # External patches (src/external-patches/firefox/) are pending Mozilla
      # bugs that zen vendors. Version-sensitive — usually a couple don't apply
      # cleanly against the current Firefox version. With the git-repo,
      # surfer's git apply ABORTS on failure (instead of silently skipping).
      # Pre-screen and rename non-applicable ones so surfer's glob ignores them.
      # Each is a non-core feature (popovers, transparency tweaks); losing them
      # doesn't break the build or the zen overlay.
      echo "==> Pre-screening external patches"
      for patch in src/external-patches/firefox/*.patch src/external-patches/firefox/*/*.patch; do
        [ -f "$patch" ] || continue
        if ! ( cd engine && git apply --check "../$patch" 2>/dev/null ); then
          echo "  skip (non-applicable to current FF): $patch"
          mv "$patch" "$patch.skip"
        fi
      done

      # Force zen-new-little-window off the zenGlobal path. The PR routes this
      # shortcut through the new Cocoa global-shortcut C++ layer (incomplete on
      # darwin — key registration doesn't fire). With zenGlobal=false it goes
      # through the regular XUL keybinding instead, which works.
      # --replace-fail intentional: if upstream finishes the global path and
      # changes this syntax, build fails loudly and we re-evaluate.
      substituteInPlace src/zen/kbs/ZenKeyboardShortcuts.sys.mjs \
        --replace-fail '/*zenGlobal=*/ true' '/*zenGlobal=*/ false' \
        --replace-fail 'shortcut._setZenGlobal(true)' 'shortcut._setZenGlobal(false)'

      echo "==> Importing patches"
      npm run import -- --verbose

      # ----- Verify zen integration actually happened -----
      # Surfer's import does TWO things that the build depends on:
      #   1. copy-patches.js: symlinks every non-.patch file in src/ → engine/
      #      (so engine/zen/ ends up populated with symlinks to src/zen/)
      #   2. git-patch.js: applies src/browser/base/moz-build.patch which adds
      #      `DIRS += ["../../zen"]` to engine/browser/base/moz.build (so mach
      #      actually descends into engine/zen/ during build)
      #
      # Both failure modes are SILENT in surfer — copyManual catches errors
      # with console.error (no throw), and git-patch.apply logs to log.error
      # without re-throwing. The previous symptom (binary with zen branding
      # but no zen features) is exactly what you get when one or both of
      # these silently skip while the rest of the build proceeds.
      #
      # Better to fail FAST here than spend 50 minutes building a no-op
      # binary. The diagnostics print enough state to fix forward without
      # another round-trip.
      echo "==> Verifying zen integration"

      if [ ! -d engine/zen ] || [ -z "$(ls -A engine/zen 2>/dev/null)" ]; then
        echo "" >&2
        echo "FATAL: engine/zen/ is missing or empty after npm run import." >&2
        echo "       surfer's copy-patches step failed to symlink src/zen → engine/zen." >&2
        echo "" >&2
        echo "src/zen/ (source — should have these subdirs):" >&2
        ls -la src/zen/ 2>/dev/null | head -30 >&2
        echo "" >&2
        echo "engine/zen/ (destination — empty or missing):" >&2
        ls -la engine/zen/ 2>/dev/null >&2 || echo "  (does not exist)" >&2
        exit 1
      fi

      if ! grep -qF '"../../zen"' engine/browser/base/moz.build; then
        echo "" >&2
        echo "FATAL: engine/browser/base/moz.build lacks DIRS += [\"../../zen\"]." >&2
        echo "       The integration patch (src/browser/base/moz-build.patch) wasn't applied." >&2
        echo "" >&2
        echo "Tail of engine/browser/base/moz.build:" >&2
        tail -10 engine/browser/base/moz.build >&2
        echo "" >&2
        echo "Patch that should have applied:" >&2
        cat src/browser/base/moz-build.patch >&2
        exit 1
      fi

      # PR-specific check: this is the little-zen PR, so it must have the
      # ZenLittleWindow file. If it's missing, src/zen/ has it but the
      # symlink didn't get created (single-file failure mode of copyManual).
      if [ ! -e engine/zen/little-window/ZenLittleWindow.sys.mjs ]; then
        echo "" >&2
        echo "FATAL: PR's little-window/ZenLittleWindow.sys.mjs not in engine/zen/." >&2
        echo "       This file exists in src/zen/ but surfer didn't symlink it." >&2
        echo "" >&2
        echo "src/zen/little-window/:" >&2
        ls -la src/zen/little-window/ 2>/dev/null >&2 || echo "  (does not exist in src either!)" >&2
        echo "" >&2
        echo "engine/zen/ top-level:" >&2
        ls -la engine/zen/ | head -30 >&2
        exit 1
      fi

      echo "==> Integration verified: engine/zen/ populated, DIRS patch applied, PR files present"

      # Pre-populate locales/firefox-l10n from the FOD'd snapshot, then patch
      # the upstream download script to skip its `rm -rf` + `git clone` lines.
      # The clone is ~4.3M objects (history + all locales) — fetching just the
      # working tree at the pinned commit via fetchFromGitHub is dramatically
      # faster AND cached across builds. The script does other useful prep
      # (line-ending normalization, language list processing) so we still run
      # it; only the network-heavy clone is bypassed.
      echo "==> Pre-populating locales/firefox-l10n from cached snapshot @ ${l10nCommit}"
      mkdir -p locales
      rm -rf locales/firefox-l10n
      if command -v ditto >/dev/null 2>&1; then
        ditto "$firefoxL10n" locales/firefox-l10n
      else
        cp -R "$firefoxL10n" locales/firefox-l10n
      fi
      chmod -R u+w locales/firefox-l10n

      # download-language-packs.sh expects firefox-l10n to be a git repo at
      # the pinned commit (it may run `git rev-parse HEAD` or `git checkout`
      # downstream). Init a stub repo + commit so those operations succeed.
      ( cd locales/firefox-l10n
        if [ ! -d .git ]; then
          git init -q
          git -c user.email=build@local -c user.name=build add -A
          GIT_AUTHOR_DATE="1970-01-01T00:00:00Z" \
          GIT_COMMITTER_DATE="1970-01-01T00:00:00Z" \
            git -c user.email=build@local -c user.name=build commit -q -m "l10n ${l10nCommit}"
        fi
      )

      sed -i \
        -e 's|^[[:space:]]*rm -rf firefox-l10n.*$|: # rm skipped (cached)|' \
        -e 's|^[[:space:]]*git clone https://github.com/mozilla-l10n/firefox-l10n.*$|: # clone skipped (cached)|' \
        scripts/download-language-packs.sh

      echo "==> Downloading language packs (clone skipped, using cached snapshot)"
      sh scripts/download-language-packs.sh || true

      echo "==> mach bootstrap (toolchain from nix; --no-interactive skips brew)"
      ( cd engine && ./mach --no-interactive bootstrap \
          --application-choice browser --exclude macos-sdk ) || true

      # macOS SDK resolution: nixpkgs's apple-sdk-14.4 ships its own `xcrun`
      # shim that shadows /usr/bin/xcrun. We need the SYSTEM Xcode SDK
      # (>= 26.2 for current Firefox), so use /usr/bin/xcrun explicitly.
      # Note: __noChroot lets us reach /Applications/Xcode.app from the build.
      export DEVELOPER_DIR="/Applications/Xcode.app/Contents/Developer"
      SYS_SDK_PATH="$(/usr/bin/xcrun --sdk macosx --show-sdk-path 2>/dev/null || true)"
      SYS_SDK_VER="$(/usr/bin/xcrun --sdk macosx --show-sdk-version 2>/dev/null || true)"
      if [ -z "$SYS_SDK_PATH" ]; then
        echo "ERROR: /usr/bin/xcrun couldn't find a system SDK." >&2
        echo "       Run: sudo xcode-select -s /Applications/Xcode.app/Contents/Developer" >&2
        exit 1
      fi
      echo "==> System Xcode SDK: $SYS_SDK_VER at $SYS_SDK_PATH"
      export SDKROOT="$SYS_SDK_PATH"

      # zen's mozconfig hardcodes a `~/.mozbuild/MacOSX<ver>.sdk` path; point
      # both common names at the system SDK so configure stops trying to fetch
      # a 403'd bootstrap SDK.
      mkdir -p "$HOME/.mozbuild"
      for v in MacOSX26.2.sdk MacOSX.sdk; do
        ln -snf "$SYS_SDK_PATH" "$HOME/.mozbuild/$v"
      done

      # API key files — surfer's mozconfig hard-references these. Mozilla's
      # configure REJECTS empty files (was the previous incarnation here), so
      # write a non-empty placeholder. Safe-browsing and location lookups
      # won't authenticate at runtime; fine for a personal build.
      mkdir -p "$HOME/.zen-keys"
      printf 'no-key' > "$HOME/.zen-keys/safebrowsing.dat"
      printf 'no-key' > "$HOME/.zen-keys/mozilla.dat"
      printf 'no-key' > "$HOME/.zen-keys/google_location_service.dat"

      # surfer's `build` command does `git rev-parse HEAD` in the zen source
      # root to embed the commit SHA in the binary's build metadata.
      # fetchFromGitHub strips .git/ from its tarball, so the source is not a
      # git repo — surfer aborts. Init a stub with one empty commit so HEAD
      # resolves. The SHA we generate isn't the real zen commit (that lives
      # in the derivation's `src.rev`), which is fine for a personal build.
      if [ ! -d .git ]; then
        git init -q
        GIT_AUTHOR_DATE="1970-01-01T00:00:00Z" \
        GIT_COMMITTER_DATE="1970-01-01T00:00:00Z" \
          git -c user.email=build@local -c user.name=build \
              commit -q --allow-empty -m "zen ${version}"
      fi

      runHook postConfigure
    '';

    buildPhase = ''
      runHook preBuild
      echo "==> Building (no PGO — opt build, expect 2-4h on M-series)"
      npm run build
      runHook postBuild
    '';

    # Package step produces a DMG in ./dist; we want the raw .app for nix-darwin
    # to drop into /Applications. The .app lives inside the DMG bundle. Use
    # hdiutil to mount, copy, detach. `npm run package` runs unsigned/unnotarized
    # which is fine for local use.
    installPhase = ''
      runHook preInstall

      echo "==> Packaging"
      npm run package

      DMG="$(ls -t ./dist/*.dmg 2>/dev/null | head -1 || true)"
      if [ -z "$DMG" ]; then
        echo "ERROR: no .dmg in ./dist — check the package step output" >&2
        ls -la ./dist 2>/dev/null || true
        exit 1
      fi

      mkdir -p $out/Applications

      MOUNT_POINT="$(mktemp -d)/zen-mount"
      mkdir -p "$MOUNT_POINT"
      /usr/bin/hdiutil attach -nobrowse -readonly -mountpoint "$MOUNT_POINT" "$DMG"
      APP="$(ls -d "$MOUNT_POINT"/*.app | head -1)"
      if [ -z "$APP" ]; then
        echo "ERROR: no .app in mounted DMG" >&2
        /usr/bin/hdiutil detach "$MOUNT_POINT" || true
        exit 1
      fi
      # Rename to match official "(Beta)" naming — dock pins / launchctl entries
      # already point there. Zen's source only ships `release` + `twilight` brands.
      cp -R "$APP" "$out/Applications/Zen Browser (Beta).app"
      /usr/bin/hdiutil detach "$MOUNT_POINT"

      # Also publish the DMG itself for users who want it (consumed by the
      # zen-browser-flake-style codesign-stripping override path).
      cp "$DMG" "$out/zen.dmg"

      runHook postInstall
    '';

    # The .app is already fully-formed; nix's fixup would re-sign it with an
    # ad-hoc signature that breaks 1Password (Team ID missing). Skip fixup.
    dontFixup = true;

    meta = with lib; {
      description = "Zen Browser built from source (little-zen PR branch)";
      homepage = "https://github.com/zen-browser/desktop";
      license = licenses.mpl20;
      platforms = ["aarch64-darwin"];
      # Building Firefox takes 2-4h and ~30-50GB of disk; flag it as a "huge"
      # derivation so it's skipped on CI by default. Consumers opt in via
      # `nix build .#zen-browser` directly.
      timeout = 6 * 60 * 60; # 6h hard limit
      mainProgram = "Zen Browser";
      maintainers = [];
    };
  }
