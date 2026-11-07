{
  lib,
  buildGoModule,
  fetchFromGitHub,
  nix-update-script,
}:
buildGoModule rec {
  pname = "kubernetes-mcp-server";
  version = "0.1.2";

  src = fetchFromGitHub {
    owner = "containers";
    repo = "kubernetes-mcp-server";
    rev = "v${version}";
    hash = "sha256-6OIdUjXRqQBASObk73A0wxfhN5ARB2tv298GPXO8jpQ=";
  };

  vendorHash = "sha256-7BoixYxAhC9/rv+L1QRGdtqoYNUxyuAsWwbaSpqzoFY=";

  subPackages = ["cmd/kubernetes-mcp-server"];

  passthru.updateScript = nix-update-script {};

  meta = with lib; {
    description = "Kubernetes MCP server for AI tools to interact with Kubernetes clusters";
    homepage = "https://github.com/containers/kubernetes-mcp-server";
    license = licenses.asl20;
    mainProgram = "kubernetes-mcp-server";
  };
}
