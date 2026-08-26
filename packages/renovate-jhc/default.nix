{
  fetchFromGitHub,
  fetchPnpmDeps,
  nix-update-script,
  pnpm_11,
  renovate,
}:
renovate.overrideAttrs (finalAttrs: prev: {
  version = "4.11.0";

  src = fetchFromGitHub {
    owner = "JHOFER-Cloud";
    repo = "renovate";
    rev = finalAttrs.version;
    hash = "sha256-B0vsIztWh+XANybZblRIV330nuLpEfH8CkkSo4LtdZM=";
  };

  pnpmDeps = fetchPnpmDeps {
    inherit (finalAttrs) pname version src;
    pnpm = pnpm_11;
    fetcherVersion = 4;
    hash = "sha256-2206DUGC3WHK3xVVPkB2QpM8/fdto+80txd2wd7vaC0=";
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
