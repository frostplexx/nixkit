{
  lib,
  stdenv,
  fetchFromGitHub,
  llvmPackages,
  nix-update-script,
  ...
}:
stdenv.mkDerivation {
  pname = "aerospace-swipe";
  version = "0-unstable-2026-06-30";

  src = fetchFromGitHub {
    owner = "acsandmann";
    repo = "aerospace-swipe";
    hash = "sha256-0SvEebMAiD7+7bGow2EeSyKuwO3qoA0YNWm1UcNkYM4=";
    rev = "fc3db8757558956e8fe1496cff3e6a9a1b1748ac";
  };

  nativeBuildInputs = [
    # Work around cctools ld64 SIGTRAP on the final link (nixpkgs regression);
    # link with LLVM lld instead. Mirrors the yabai package fix.
    llvmPackages.lld
  ];

  env.NIX_CFLAGS_LINK = "-fuse-ld=lld";

  postPatch = ''
    # Fix compatibility with older SDK versions
    substituteInPlace src/haptic.c \
      --replace-fail "kIOMainPortDefault" "kIOMasterPortDefault"

    # Fix duplicate symbol error - make g_event_tap extern in header
    substituteInPlace src/event_tap.h \
      --replace-fail "struct event_tap g_event_tap;" "extern struct event_tap g_event_tap;"

    # Define g_event_tap in event_tap.m
    echo "" >> src/event_tap.m
    echo "struct event_tap g_event_tap;" >> src/event_tap.m
  '';

  buildPhase = ''
    make swipe
  '';

  installPhase = ''
    mkdir -p $out/bin
    cp swipe $out/bin/aerospace-swipe
  '';

  passthru.updateScript = nix-update-script {extraArgs = ["--version=branch"];};

  meta = with lib; {
    description = "switch workspaces in AeroSpace with trackpad swipes";
    homepage = "https://github.com/acsandmann/aerospace-swipe";
    platforms = platforms.darwin;
  };
}
