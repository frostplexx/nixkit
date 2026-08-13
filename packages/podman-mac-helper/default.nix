{
  lib,
  buildGoModule,
  fetchFromGitHub,
  nix-update-script,
  ...
}:
buildGoModule rec {
  pname = "podman-mac-helper";
  version = "6.1.0";

  src = fetchFromGitHub {
    owner = "containers";
    repo = "podman";
    rev = "v${version}";
    sha256 = "sha256-wjqB8sQY7Ovz4bY4dBWfLDD7qvu8EA1KubVp6ocWle8=";
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

