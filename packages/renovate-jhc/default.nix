{
  fetchFromGitHub,
  fetchPnpmDeps,
  nix-update-script,
  pnpm_11,
  renovate,
}:
renovate.overrideAttrs (finalAttrs: prev: {
  version = "4.20.0";

  src = fetchFromGitHub {
    owner = "JHOFER-Cloud";
    repo = "renovate";
    rev = finalAttrs.version;
    hash = "sha256-5A+Co+r1TLM5s+dviBzyv0iUnKEZFVaJ1rYr9Gu7oB0=";
  };

  pnpmDeps = fetchPnpmDeps {
    inherit (finalAttrs) pname version src;
    pnpm = pnpm_11;
    fetcherVersion = 4;
    hash = "sha256-hYSYhqUhkjX3Sf6fCZZaOvbcm3AFK9L3gn6ycDdonWs=";
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
