final: prev:

let
  packages = import ./packages { pkgs = final; };
in

# Make packages available at top level
packages
// {
  # Also make Python packages available in python packages for easier access
  python3 = prev.python3.override {
    packageOverrides = pyfinal: pyprev: {
      inherit (packages) dimclient ndcli;
    };
  };
  python3Packages = final.python3.pkgs;
}
