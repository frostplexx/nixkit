_: prev: let
  packages = import ./packages {
    pkgs = prev;
    inherit (prev.stdenv.hostPlatform) system;
  };
in
  packages
  // {
    python3 = prev.python3.override {
      packageOverrides = _pyfinal: _pyprev: {
        inherit (packages) dimclient ndcli;
      };
    };
    vimPlugins =
      prev.vimPlugins
      // {
        inherit (packages) prlsp-nvim;
      };
  }
