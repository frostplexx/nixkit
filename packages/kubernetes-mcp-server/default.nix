{
  lib,
  buildGoModule,
  fetchFromGitHub,
  nix-update-script,
}:
buildGoModule rec {
  pname = "kubernetes-mcp-server";
  version = "0.0.62";

  src = fetchFromGitHub {
    owner = "containers";
    repo = "kubernetes-mcp-server";
    rev = "v${version}";
    hash = "sha256-m4oM8KMcDmXwIGaFw+VdnW22kLjt2SaD7qZV4kgTiu8=";
  };

  vendorHash = "sha256-JNeYn/IfzQ2VLDbHgrkserh3wrXYOWXBczBn2DUO6NM=";

  subPackages = ["cmd/kubernetes-mcp-server"];

  passthru.updateScript = nix-update-script {};

  meta = with lib; {
    description = "Kubernetes MCP server for AI tools to interact with Kubernetes clusters";
    homepage = "https://github.com/containers/kubernetes-mcp-server";
    license = licenses.asl20;
    mainProgram = "kubernetes-mcp-server";
  };
}
