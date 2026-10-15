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
  version = "0.15.1";

  src = fetchFromGitHub {
    owner = "geelen";
    repo = "mcp-remote";
    rev = "v${finalAttrs.version}";
    hash = "sha256-pykcdEoim08npawyWOXf8PR60f+SedxEuuynWSwj5t0=";
  };

  pnpmDeps = fetchPnpmDeps {
    inherit (finalAttrs) pname version src;
    fetcherVersion = 4;
    # pnpm 11 leaves an empty v11/links dir in the store on darwin but not on
    # linux, so the hash would differ per platform. Drop it before packing.
    preFixup = ''
      rm -rf $storePath/v11/links
    '';
    hash = "sha256-h1Rh3xDw6mpCBWfh+fjfWtZ8WrdziEL2d6S+k9VaghQ=";
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

    # pnpm 12's prune verifies the lockfile against the registry, which the
    # sandbox can't reach; an offline --prod reinstall gets the same result.
    rm -rf node_modules
    pnpm install --offline --prod --ignore-scripts --frozen-lockfile

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
