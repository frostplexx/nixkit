{
  lib,
  buildGoLatestModule,
  fetchFromGitHub,
  nix-update-script,
}:
buildGoLatestModule rec {
  pname = "topf";
  version = "0.6.2";

  src = fetchFromGitHub {
    owner = "postfinance";
    repo = "topf";
    rev = "v${version}";
    hash = "sha256-frUyZtpA0iyFwHxlN5SqZ0WFfU4sMalmdkHtulg+B3I=";
  };

  vendorHash = "sha256-VLZLPM1/a1Lf5ggk4pwB/AL+Drrdfmm3f9DYjvpBKcA=";

  subPackages = ["cmd/topf"];

  ldflags = ["-s" "-w" "-X" "main.version=${version}"];

  passthru.updateScript = nix-update-script {};

  meta = with lib; {
    description = "Talos Orchestrator by PostFinance for managing Talos based Kubernetes clusters";
    homepage = "https://github.com/postfinance/topf";
    license = licenses.mit;
    mainProgram = "topf";
  };
}
