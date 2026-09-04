{
  lib,
  buildGoModule,
  fetchFromGitHub,
  nix-update-script,
}:
buildGoModule rec {
  pname = "topf";
  version = "0.6.0";

  src = fetchFromGitHub {
    owner = "postfinance";
    repo = "topf";
    rev = "v${version}";
    hash = "sha256-NRKRROq6uxLlAHCtpT+s+eBVjFgf8qjjwlYGhdNApUs=";
  };

  vendorHash = "sha256-9xYy1Ep7bZ0nW63fmrxiqfOrHWt7Kcn+zGhcjBpdvYY=";

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
