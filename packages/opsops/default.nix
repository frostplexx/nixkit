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
  version = "1.3.4";

  src = fetchFromGitHub {
    owner = "frostplexx";
    repo = "opsops";
    rev = "v${version}";
    sha256 = "sha256-gfoc9EHpVFdKA4uH0w3Chy1p3uI6TIu1H5J6E6BxXz8=";
  };

  cargoHash = "sha256-V6ZmJnz43QeP4fNkT8SW2w4jysPpyOV3algQWnJeLeU=";

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
