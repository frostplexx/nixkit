{
  lib,
  stdenv,
  fetchFromGitHub,
  ...
}:

stdenv.mkDerivation {

    pname = "aerospace-swipe";
    version = "1.0.0";

    src = fetchFromGitHub {
      owner = "acsandmann";
      repo = "aerospace-swipe";
      hash = "sha256-ZLaE/CuUgpWXrmV0cKLI8L9R92REECxWcpOwofMDMx4=";
      rev =  "1845e0e99c4c4bb34453253189a437a698ddbdc8";
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


    meta = with lib; {
        description = "switch workspaces in AeroSpace with trackpad swipes";
        homepage = "https://github.com/acsandmann/aerospace-swipe";
        platforms = platforms.darwin;
    };
}
