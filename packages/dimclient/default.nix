{
  lib,
  python3Packages,
  fetchFromGitHub,
}:

python3Packages.buildPythonPackage rec {
  pname = "dimclient";
  version = "5.0.4";
  format = "pyproject";

  src = fetchFromGitHub {
    owner = "ionos-cloud";
    repo = "dim";
    rev = "ndcli-${version}";
    sha256 = "sha256-s+4UgeJkqojtM73miE9hr7C8HduXJRHDIFfJxL2wZQ4=";
  };

  sourceRoot = "source/dimclient";

  nativeBuildInputs = with python3Packages; [
    setuptools
    pip
    wheel
  ];

  meta = with lib; {
    description = "Python client for DIM (DNS and IP Management)";
    homepage = "https://github.com/ionos-cloud/dim";
    platforms = platforms.unix;
  };
}
