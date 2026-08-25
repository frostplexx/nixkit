{
  lib,
  buildGo127Module,
  fetchFromGitHub,
  installShellFiles,
  stdenv,
  nix-update-script,
}:
buildGo127Module rec {
  pname = "flate";
  version = "0.6.0";

  src = fetchFromGitHub {
    owner = "home-operations";
    repo = "flate";
    rev = "v${version}";
    hash = "sha256-Y4P3RQEkVI3HJvJd8cQmSC65RJYNKGxzB8LvnqgGVfQ=";
  };

  vendorHash = "sha256-REVrrpO7Wbd3jj+2x1eLODLiXfpLvnYkS1o5wp3mGm0=";

  subPackages = ["cmd/flate"];

  ldflags = ["-s" "-w" "-X" "main.version=${version}"];

  nativeBuildInputs = [installShellFiles];

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
