{
  lib,
  buildGoModule,
  fetchFromGitHub,
  nix-update-script,
  ...
}:
buildGoModule rec {
  pname = "podman-mac-helper";
  version = "6.2.0";

  src = fetchFromGitHub {
    owner = "containers";
    repo = "podman";
    rev = "v${version}";
    sha256 = "sha256-3U0z3ZuiSOR4xGju3xJKsg8X1QxSaoN9Am7wkrFzKdY=";
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
