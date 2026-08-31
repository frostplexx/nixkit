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
  version = "0.6.2";

  src = fetchFromGitHub {
    owner = "home-operations";
    repo = "flate";
    rev = "v${version}";
    hash = "sha256-omjnwWCSoj/OU7O4vGwK4qkCoPT+kv/IP8s99AQ3eQs=";
  };

  vendorHash = "sha256-pKO/oahZDvk3HVOSSFv/Qw0inRMUx35W6VTOYeEnD3Q=";

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
