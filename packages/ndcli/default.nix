{
  lib,
  python3Packages,
  fetchFromGitHub,
  dimclient,
}:

python3Packages.buildPythonPackage rec {
  pname = "ndcli";
  version = "5.0.4";
  format = "pyproject";

  src = fetchFromGitHub {
    owner = "ionos-cloud";
    repo = "dim";
    rev = "ndcli-${version}";
    sha256 = "sha256-s+4UgeJkqojtM73miE9hr7C8HduXJRHDIFfJxL2wZQ4=";
  };

  sourceRoot = "source/ndcli";

  nativeBuildInputs = with python3Packages; [
    setuptools
    pip
    wheel
  ];

  propagatedBuildInputs = [
    dimclient
    python3Packages.python-dateutil
    python3Packages.dnspython
  ];

  meta = with lib; {
    description = "Command line interface for DIM (DNS and IP Management)";
    homepage = "https://github.com/ionos-cloud/dim";
    platforms = platforms.unix;
  };
}
