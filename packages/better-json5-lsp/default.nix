{
  lib,
  stdenv,
  fetchFromGitHub,
  nodejs,
  yarn-berry_4,
  makeWrapper,
  nix-update-script,
}:
stdenv.mkDerivation (finalAttrs: {
  pname = "better-json5-lsp";
  version = "1.7.0-unstable-2026-10-27";

  # Upstream publishes no tags or GitHub releases, only the VS Code extension.
  # TODO: back to BlueGlassBlock once the yarn.lock v10 bump is merged upstream
  # (nixpkgs' yarn-berry_4 can't install the v8 lockfile offline).
  src = fetchFromGitHub {
    owner = "ojsef39";
    repo = "better-json5";
    rev = "d8428b6b3e0965373c2cea1a1c959c0bce4dfa92";
    hash = "sha256-XbXeasdSz5N6hvUoafR6ZQiJYa4+wh3UItAgzjlBBCw=";
  };

  # Platform-specific optional deps (esbuild, ...) have no checksum in
  # yarn.lock. Regenerate when they change:
  #   yarn-berry-fetcher missing-hashes yarn.lock > missing-hashes.json
  missingHashes = ./missing-hashes.json;
  offlineCache = yarn-berry_4.fetchYarnBerryDeps {
    inherit (finalAttrs) src missingHashes;
    hash = "sha256-Zn1XzTHf+LwK8VX/3v7CyAZP4ijSTfddJ4smZiMYk5g=";
  };

  nativeBuildInputs = [
    nodejs
    yarn-berry_4
    yarn-berry_4.yarnBerryConfigHook
    makeWrapper
  ];

  buildPhase = ''
    runHook preBuild
    node esbuild.mjs --production
    runHook postBuild
  '';

  # esbuild bundles every dependency, so the server is a single file.
  installPhase = ''
    runHook preInstall

    install -Dm644 dist/node/serverMain.js $out/lib/better-json5-lsp/serverMain.js
    makeWrapper ${lib.getExe nodejs} $out/bin/better-json5-language-server \
      --add-flags $out/lib/better-json5-lsp/serverMain.js

    runHook postInstall
  '';

  passthru.updateScript = nix-update-script {extraArgs = ["--version=branch"];};

  meta = {
    description = "JSON5 language server (schema validation, completion, hover) from the better-json5 VS Code extension";
    homepage = "https://github.com/BlueGlassBlock/better-json5";
    license = lib.licenses.mit;
    mainProgram = "better-json5-language-server";
    platforms = lib.platforms.unix;
  };
})
