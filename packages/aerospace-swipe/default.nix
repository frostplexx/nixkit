{
  lib,
  stdenv,
  fetchFromGitHub,
  nix-update-script,
  ...
}:

stdenv.mkDerivation {

    pname = "aerospace-swipe";
    version = "0-unstable-2025-11-17";

    src = fetchFromGitHub {
      owner = "acsandmann";
      repo = "aerospace-swipe";
      hash = "sha256-ARJfYiWXBCvXA5JlFl/s4VIQ9xuqBoU3gPfC8B2mkWI=";
      rev =  "976c3107f6ed9859149bdc130e3f8928f2ab6852";
    };

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


    passthru.updateScript = nix-update-script { extraArgs = [ "--version=branch" ]; };

    meta = with lib; {
        description = "switch workspaces in AeroSpace with trackpad swipes";
        homepage = "https://github.com/acsandmann/aerospace-swipe";
        platforms = platforms.darwin;
    };
}
