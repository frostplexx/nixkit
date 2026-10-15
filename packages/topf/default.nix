{
  lib,
  buildGoLatestModule,
  fetchFromGitHub,
  nix-update-script,
}:
buildGoLatestModule rec {
  pname = "topf";
  version = "0.6.1";

  src = fetchFromGitHub {
    owner = "postfinance";
    repo = "topf";
    rev = "v${version}";
    hash = "sha256-avrcOu+6hGqr/wtxQl/ysf7E76b+XtGf2lxDrJqnzJY=";
  };

  vendorHash = "sha256-yxQCn9S0U5AjxJUmTt/eKopnZ1W+J6Zj8QaTS7W1X0w=";

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
