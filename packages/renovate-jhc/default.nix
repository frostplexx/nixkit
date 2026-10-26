{
  fetchFromGitHub,
  fetchPnpmDeps,
  nix-update-script,
  pnpm_11,
  renovate,
}:
renovate.overrideAttrs (finalAttrs: prev: {
  version = "4.29.2";

  src = fetchFromGitHub {
    owner = "JHOFER-Cloud";
    repo = "renovate";
    rev = finalAttrs.version;
    hash = "sha256-NIu9CVIB+96GUScs3N1+GyEYo3LlsaqzL2xMXgnG8kc=";
  };

  pnpmDeps = fetchPnpmDeps {
    inherit (finalAttrs) pname version src;
    pnpm = pnpm_11;
    fetcherVersion = 4;
    hash = "sha256-S1Dpb00boXh6fsAeyrMZZS9QqobfuIjnVV4XbwhGbMg=";
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
