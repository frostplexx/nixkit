{
  lib,
  buildGoModule,
  fetchFromGitHub,
  nix-update-script,
}:
buildGoModule rec {
  pname = "kubernetes-mcp-server";
  version = "0.0.65";

  src = fetchFromGitHub {
    owner = "containers";
    repo = "kubernetes-mcp-server";
    rev = "v${version}";
    hash = "sha256-EycenZ4378bOrv/MxlSxhtggq5lz8sFv0l+HiGXNjpw=";
  };

  vendorHash = "sha256-ddR/LQuldt+gHkUe3wqyrFMtUaN7dfBkDkThHxLmlYM=";

  subPackages = ["cmd/kubernetes-mcp-server"];

  passthru.updateScript = nix-update-script {};

  meta = with lib; {
    description = "Kubernetes MCP server for AI tools to interact with Kubernetes clusters";
    homepage = "https://github.com/containers/kubernetes-mcp-server";
    license = licenses.asl20;
    mainProgram = "kubernetes-mcp-server";
  };
}
