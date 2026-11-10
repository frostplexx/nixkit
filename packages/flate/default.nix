{
  lib,
  buildGo127Module,
  fetchFromGitHub,
  installShellFiles,
  stdenv,
  pkgs,
  nix-update-script,
}:
buildGo127Module rec {
  pname = "flate";
  version = "0.7.3";

  src = fetchFromGitHub {
    owner = "home-operations";
    repo = "flate";
    rev = "v${version}";
    hash = "sha256-sm22CX+3B7roECyNz5v9yLaqlTPZN7GWMcNthBn5IpY=";
  };

  vendorHash = "sha256-TyYkEU+UbN2B+rj0D3QxwEOGpwLKwHW9jZT/kitPYn8=";

  subPackages = ["cmd/flate"];

  ldflags = ["-s" "-w" "-X" "main.version=${version}"];

  nativeBuildInputs = [installShellFiles pkgs.go_1_27];

  postInstall = lib.optionalString (stdenv.buildPlatform.canExecute stdenv.hostPlatform) ''
    installShellCompletion --cmd flate \
      --bash <($out/bin/flate completion bash) \
      --fish <($out/bin/flate completion fish) \
      --zsh <($out/bin/flate completion zsh)
  '';

  passthru.updateScript = nix-update-script {};

  meta = with lib; {
    description = "Render and diff Flux GitOps repositories offline, without a cluster";
    homepage = "https://github.com/home-operations/flate";
    license = licenses.agpl3Only;
    mainProgram = "flate";
  };
}
