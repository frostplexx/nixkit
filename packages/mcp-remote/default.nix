{
  lib,
  stdenv,
  fetchFromGitHub,
  nodejs,
  pnpm,
  pnpmConfigHook,
  fetchPnpmDeps,
  makeWrapper,
  nix-update-script,
}:
stdenv.mkDerivation (finalAttrs: {
  pname = "mcp-remote";
  version = "0.14.2";

  src = fetchFromGitHub {
    owner = "geelen";
    repo = "mcp-remote";
    rev = "v${finalAttrs.version}";
    hash = "sha256-b3IEAVwxTb2c/2ENRgQqluuZ5BE3alXsqProDwWQ1eA=";
  };

  pnpmDeps = fetchPnpmDeps {
    inherit (finalAttrs) pname version src;
    fetcherVersion = 4;
    hash = "sha256-pqZIsJos1thOuLoJtRDYPNldhAaaLDlqjdfQ0ntKA/4=";
  };

  nativeBuildInputs = [
    nodejs
    pnpm
    pnpmConfigHook
    makeWrapper
  ];

  buildPhase = ''
    runHook preBuild
    pnpm build
    runHook postBuild
  '';

  # tsup externalises everything in dependencies, so dist alone does not run:
  # express, open, undici and strict-url-sanitise have to ship alongside it.
  installPhase = ''
    runHook preInstall

    pnpm prune --prod --ignore-scripts

    mkdir -p $out/lib/mcp-remote
    cp -r dist node_modules package.json $out/lib/mcp-remote/

    makeWrapper ${lib.getExe nodejs} $out/bin/mcp-remote \
      --add-flags $out/lib/mcp-remote/dist/proxy.js
    makeWrapper ${lib.getExe nodejs} $out/bin/mcp-remote-client \
      --add-flags $out/lib/mcp-remote/dist/client.js

    runHook postInstall
  '';

  passthru.updateScript = nix-update-script {};

  meta = {
    description = "Proxy that lets stdio-only MCP clients connect to remote MCP servers";
    homepage = "https://github.com/geelen/mcp-remote";
    license = lib.licenses.mit;
    mainProgram = "mcp-remote";
    platforms = lib.platforms.unix;
  };
})
