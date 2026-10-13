{
  lib,
  buildGoModule,
  fetchFromGitHub,
  nix-update-script,
  ...
}:
buildGoModule rec {
  pname = "podman-mac-helper";
  version = "6.1.4";

  src = fetchFromGitHub {
    owner = "containers";
    repo = "podman";
    rev = "v${version}";
    sha256 = "sha256-RTPxNoKRqFGDFEYHUwPbsNAAZqNfBXbetfphxrwn6eM=";
  };

  subPackages = ["cmd/podman-mac-helper"];

  vendorHash = null;

  passthru.updateScript = nix-update-script {};

  meta = with lib; {
    description = "Helper binary for running Podman on macOS";
    homepage = "https://github.com/containers/podman";
    license = licenses.asl20;
    platforms = platforms.darwin;
  };
}
