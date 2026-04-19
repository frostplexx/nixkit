{
  lib,
  python3Packages,
  fetchPypi,
}: let
  pyproject-toml = python3Packages.buildPythonPackage rec {
    pname = "pyproject-toml";
    version = "0.1.0";
    format = "setuptools";
    src = fetchPypi {
      pname = builtins.replaceStrings ["-"] ["_"] pname;
      inherit version;
      sha256 = "sha256-d3LSYRP7ilkyiAzxyZiYeZW7EOg08Le+X0b26onwZFA=";
    };
    nativeBuildInputs = with python3Packages; [setuptools];
    preBuild = "echo 'from setuptools import setup; setup()' > setup.py";
    doCheck = false;
  };

  griffelib = python3Packages.buildPythonPackage rec {
    pname = "griffelib";
    version = "2.0.0";
    pyproject = true;
    src = fetchPypi {
      inherit pname version;
      sha256 = "sha256-5QTWN6CJ9cq5tdrxj3ZFlwUJv09T7ajXntcczovZeTQ=";
    };
    nativeBuildInputs = with python3Packages; [pdm-backend uv-dynamic-versioning];
    doCheck = false;
  };

  uncalled-for = python3Packages.buildPythonPackage rec {
    pname = "uncalled-for";
    version = "0.2.0";
    pyproject = true;
    src = fetchPypi {
      pname = builtins.replaceStrings ["-"] ["_"] pname;
      inherit version;
      sha256 = "sha256-tPj9vOwyjFoROAfWU+BBxQlEc91K+nw0WZrOacy35p8=";
    };
    nativeBuildInputs = with python3Packages; [hatchling hatch-vcs];
    doCheck = false;
  };

  py-key-value-aio = python3Packages.py-key-value-aio.overridePythonAttrs (_: rec {
    version = "0.4.4";
    src = fetchPypi {
      pname = builtins.replaceStrings ["-"] ["_"] "py-key-value-aio";
      inherit version;
      sha256 = "sha256-4wEuYkPtfMCbsFRXvU0DsbpcKxyocACWs5J9t5/7vlU=";
    };
    sourceRoot = "py_key_value_aio-${version}";
    pythonImportsCheck = [];
    doCheck = false;
  });

  # Override py-key-value-aio at scope level so all transitive deps pick up 0.4.4
  pyScope = python3Packages.overrideScope (_: prev: {
    py-key-value-aio = py-key-value-aio;
  });

  fastmcp = pyScope.fastmcp.overridePythonAttrs (old: rec {
    version = "3.2.4";
    src = fetchPypi {
      inherit (old) pname;
      inherit version;
      sha256 = "sha256-CD7LdbRKQWnn/A9jL5S3gb2w/4d8azW5h3y7Vm/U1NE=";
    };
    propagatedBuildInputs = (old.propagatedBuildInputs or []) ++ [
      griffelib
      py-key-value-aio
      uncalled-for
      python3Packages.watchfiles
    ];
    doCheck = false;
  });
in
  python3Packages.buildPythonApplication rec {
    pname = "prometheus-mcp-server";
    version = "1.6.0";
    pyproject = true;

    src = fetchPypi {
      pname = builtins.replaceStrings ["-"] ["_"] pname;
      inherit version;
      sha256 = "sha256-Ot2ii/RPWgpz6HmWadGBsE+8+Rmm5zRKH9YFO8mE2yk=";
    };

    nativeBuildInputs = with python3Packages; [setuptools];

    propagatedBuildInputs = with python3Packages; [
      fastmcp
      mcp
      prometheus-api-client
      pyproject-toml
      python-dotenv
      requests
      structlog
    ];

    doCheck = false;

    meta = with lib; {
      description = "MCP server for Prometheus integration";
      homepage = "https://github.com/pab1it0/prometheus-mcp-server";
      license = licenses.mit;
      mainProgram = "prometheus-mcp-server";
    };
  }
