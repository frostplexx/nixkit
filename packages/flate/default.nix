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
  version = "0.8.0";

  src = fetchFromGitHub {
    owner = "home-operations";
    repo = "flate";
    rev = "v${version}";
    hash = "sha256-5RmeAjozWNSWkPI1KQRhUcVKYRrtArnr86pKBSFT4HU=";
  };

  vendorHash = "sha256-8MwEycLWR5E6nC83Kwz8R3h6sMxj3+2pxnFGFZ3I4YA=";

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
