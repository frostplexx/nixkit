{
  fetchFromGitHub,
  fetchPnpmDeps,
  nix-update-script,
  pnpm_11,
  renovate,
}:
renovate.overrideAttrs (finalAttrs: prev: {
  version = "4.37.0";

  src = fetchFromGitHub {
    owner = "JHOFER-Cloud";
    repo = "renovate";
    rev = finalAttrs.version;
    hash = "sha256-c87YfX0hjd7c1qHJP5HpX3FHKI+RH4kWVAQ7G3IA4EQ=";
  };

  pnpmDeps = fetchPnpmDeps {
    inherit (finalAttrs) pname version src;
    pnpm = pnpm_11;
    fetcherVersion = 4;
    hash = "sha256-YTfqb3HEldOEr00gHfc7p9xSXhBm6wBl49k8KCGrA0g=";
  };

  passthru.updateScript = nix-update-script {extraArgs = ["--version-regex" "^(\\d+\\.\\d+\\.\\d+)$"];};

  meta =
    prev.meta
    // {
      description = "Cross-platform Dependency Automation by Mend.io (JHOFER-Cloud fork)";
      homepage = "https://github.com/JHOFER-Cloud/renovate";
      changelog = "https://github.com/JHOFER-Cloud/renovate/releases/tag/${finalAttrs.version}";
    };
})
