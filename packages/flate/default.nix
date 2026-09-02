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
  version = "0.6.5";

  src = fetchFromGitHub {
    owner = "home-operations";
    repo = "flate";
    rev = "v${version}";
    hash = "sha256-Z1bhf54xJSrCiLgRfzGuZ7ORzLgdFe5PfEVZzs8hkew=";
  };

  vendorHash = "sha256-6ZmGkdHW2/8wk/dKN9MkB+JF0/GFIw2TxZHeWShLsQ0=";

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
