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

  postInstall = ''
    # Install bash completions
    mkdir -p $out/share/bash-completion/completions
    cp bash_completion.d/ndcli $out/share/bash-completion/completions/ndcli

    # Install fish completions
    mkdir -p $out/share/fish/vendor_completions.d
    cat > $out/share/fish/vendor_completions.d/ndcli.fish <<'EOF'
# Fish completion for ndcli
# ndcli uses bash programmable completion, so we wrap it for fish
function __ndcli_complete
    set -l cmd (commandline -cp)
    set -l COMP_LINE "$cmd"
    set -l COMP_POINT (string length "$COMP_LINE")
    env COMP_LINE="$COMP_LINE" COMP_POINT=$COMP_POINT ndcli | string split ' '
end

complete -c ndcli -f -a '(__ndcli_complete)'
EOF
  '';

  meta = with lib; {
    description = "Command line interface for DIM (DNS and IP Management)";
    homepage = "https://github.com/ionos-cloud/dim";
    platforms = platforms.unix;
  };
}
