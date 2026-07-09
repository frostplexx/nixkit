{
  lib,
  buildGoModule,
  fetchFromGitHub,
  nix-update-script,
  ...
}:
buildGoModule rec {
  pname = "podman-mac-helper";
  version = "6.0.1";

  src = fetchFromGitHub {
    owner = "containers";
    repo = "podman";
    rev = "v${version}";
    sha256 = "sha256-EUoxguIMBhpUBOtfNyA7rxPE2y1tB+Y2lu0UVHpXe8o=";
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

