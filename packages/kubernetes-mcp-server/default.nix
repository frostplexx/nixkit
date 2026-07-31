{
  lib,
  buildGoModule,
  fetchFromGitHub,
  nix-update-script,
}:
buildGoModule rec {
  pname = "kubernetes-mcp-server";
  version = "0.0.66";

  src = fetchFromGitHub {
    owner = "containers";
    repo = "kubernetes-mcp-server";
    rev = "v${version}";
    hash = "sha256-vnJxSCfnpvOZJXQpKrCAW4QKt5R2PJDYQevA7O1uXZg=";
  };

  vendorHash = "sha256-gbqoT4X+wVOEktHm7jaAH9vHrUBrYgR8OjyFz1ljP6k=";

  subPackages = ["cmd/kubernetes-mcp-server"];

  passthru.updateScript = nix-update-script {};

  meta = with lib; {
    description = "Kubernetes MCP server for AI tools to interact with Kubernetes clusters";
    homepage = "https://github.com/containers/kubernetes-mcp-server";
    license = licenses.asl20;
    mainProgram = "kubernetes-mcp-server";
  };
}
