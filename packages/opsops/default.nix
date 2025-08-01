{
  lib,
  rustPlatform,
  fetchFromGitHub,
  pkg-config,
  openssl,
  sops,
}:

rustPlatform.buildRustPackage rec {
  pname = "opsops";
  version = "1.3.1";

  src = fetchFromGitHub {
    owner = "frostplexx";
    repo = "opsops";
    rev = "v${version}";
    sha256 = "sha256-sUEtf3q3oB2og1Ed8v7qg3K1nWZy2Rp30iwqxd4HBzk=";
  };

  cargoHash = "sha256-S9HQwv9N33T1Q8c3dm7hQSyQzG0wIa7O0k/gaJa3S7w=";

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

  meta = with lib; {
    description = "A simple tool for managing secrets (with 1password integration)";
    homepage = "https://github.com/frostplexx/opsops";
    license = licenses.mit;
    mainProgram = "opsops";
  };
}
