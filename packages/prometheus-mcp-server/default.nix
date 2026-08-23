{
  lib,
  python3Packages,
  fetchPypi,
  nix-update-script,
}:
  python3Packages.buildPythonApplication rec {
    pname = "prometheus-mcp-server";
    version = "1.6.2";
    pyproject = true;

    src = fetchPypi {
      pname = builtins.replaceStrings ["-"] ["_"] pname;
      inherit version;
      sha256 = "sha256-KPjbAin4JdniBYW6hknwZeK7dkisf5/oYVjh5pV/Gn4=";
    };

    nativeBuildInputs = with python3Packages; [setuptools];

    propagatedBuildInputs = with python3Packages; [
      fastmcp
      python-dotenv
      requests
      structlog
    ];

    doCheck = false;

    passthru.updateScript = nix-update-script {};

    meta = with lib; {
      description = "MCP server for Prometheus integration";
      homepage = "https://github.com/pab1it0/prometheus-mcp-server";
      license = licenses.mit;
      mainProgram = "prometheus-mcp-server";
    };
  }
