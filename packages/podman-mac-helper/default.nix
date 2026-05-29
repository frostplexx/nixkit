{
  lib,
  buildGoModule,
  fetchFromGitHub,
  nix-update-script,
  ...
}:
buildGoModule rec {
  pname = "podman-mac-helper";
  version = "5.8.2";

  src = fetchFromGitHub {
    owner = "containers";
    repo = "podman";
    rev = "v${version}";
    sha256 = "sha256-WUcM594sUerb7/SsAu0PkpOyYuIMjaosr8Bp6d36dYk=";
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

