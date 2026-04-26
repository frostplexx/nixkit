{
  lib,
  rustPlatform,
  fetchFromGitHub,
  pkg-config,
  openssl,
  sops,
  nix-update-script,
}:
rustPlatform.buildRustPackage rec {
  pname = "opsops";
  version = "1.3.5";

  src = fetchFromGitHub {
    owner = "frostplexx";
    repo = "opsops";
    rev = "v${version}";
    sha256 = "sha256-sCd1DeNO//d1LnzB8FOeNAIrHRYy5lxHZ5G6PYVE9ig=";
  };

  cargoHash = "sha256-dw2WmGNZ4vFaOES13Yfg9OSJu0HO0qSZ52P177ZKEk0=";

  nativeBuildInputs = [
    pkg-config
    sops
  ];
  buildInputs = [
    openssl
    sops
  ];

  postInstall = ''
    # Create directories for docs
    mkdir -p $out/share/man/man1
    mkdir -p $out/share/fish/vendor_completions.d

    # Generate docs
    $out/bin/opsops generate-docs --dir $TMPDIR/docs

    # Install man page
    cp $TMPDIR/docs/man/opsops.1 $out/share/man/man1/

    # Install fish completions
    cp $TMPDIR/docs/completions/opsops.fish $out/share/fish/vendor_completions.d/
  '';

  passthru.updateScript = nix-update-script {};

  meta = with lib; {
    description = "A simple tool for managing secrets (with 1password integration)";
    homepage = "https://github.com/frostplexx/opsops";
    license = licenses.mit;
    mainProgram = "opsops";
  };
}
