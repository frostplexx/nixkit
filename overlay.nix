# Serve the packages this flake already built against its OWN nixpkgs instead of
# rebuilding them against the consumer's.
#
# nixkit's packages pin dependency hashes (fetchPnpmDeps, cargoHash, ...) that are
# only valid for the nixpkgs nixkit is locked to, and the CI binaries on
# nixkit.cachix.org only match those derivations. Building them against a
# consumer's nixpkgs silently misses the cache and, once the two diverge far
# enough, fails outright -- e.g. mcp-remote's pnpmDeps hash is computed with
# pnpm 11 and cannot be reproduced by pnpm 12.
self: _final: prev: let
  nixkitPkgs =
    builtins.removeAttrs self.packages.${prev.stdenv.hostPlatform.system}
    ["manpages" "manualHTML" "optionsJSON" "website"];
in
  nixkitPkgs
  // {
    # NOTE: these are built against nixkit's python3 but injected into the
    # consumer's package set. Safe only while both nixpkgs agree on the python3
    # minor version; if they diverge, take these two from `prev` instead.
    python3 = prev.python3.override {
      packageOverrides = _pyfinal: _pyprev: {
        inherit (nixkitPkgs) dimclient ndcli;
      };
    };
    vimPlugins =
      prev.vimPlugins
      // {
        inherit (nixkitPkgs) prlsp-nvim;
      };
  }
