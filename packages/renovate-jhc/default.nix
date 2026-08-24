{
  fetchFromGitHub,
  fetchPnpmDeps,
  nix-update-script,
  pnpm_11,
  renovate,
}:
renovate.overrideAttrs (finalAttrs: prev: {
  version = "4.9.1";

  src = fetchFromGitHub {
    owner = "JHOFER-Cloud";
    repo = "renovate";
    rev = finalAttrs.version;
    hash = "sha256-RT86N2CF4lLWhpopwtxRWrFUksb8hpTI1xnMsWesm1k=";
  };

  pnpmDeps = fetchPnpmDeps {
    inherit (finalAttrs) pname version src;
    pnpm = pnpm_11;
    fetcherVersion = 4;
    hash = "sha256-/zAdvA4AlvFEArS3Zk36P+Khu+5n9teR9J0Na0JGDd0=";
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
