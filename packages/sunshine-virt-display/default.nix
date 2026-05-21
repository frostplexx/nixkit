{
  lib,
  stdenv,
  fetchFromGitHub,
  makeWrapper,
  python3,
  bash,
  coreutils,
  libdrm,
  nix-update-script,
}: let
  version = "2.0.0";
  pythonEnv = python3.withPackages (ps: [ps.jeepney]);
in
  stdenv.mkDerivation {
    pname = "sunshine-virt-display";
    inherit version;

    src = fetchFromGitHub {
      owner = "OKlueck";
      repo = "sunshine_virt_display";
      rev = "fix/nvidia-hyprland-safe-restore";
      sha256 = "sha256-rrTNG6N6McR9UqRePgHiMkPe8yF2gA5B4XsHZco/vVA=";
    };

    nativeBuildInputs = [makeWrapper];

    dontBuild = true;

    postPatch = ''
            substituteInPlace src/display.py \
              --replace-fail 'SCRIPT_DIR = Path(__file__).parent.parent.absolute()' \
                             'SCRIPT_DIR = Path(__file__).parent.parent.absolute()
      DATA_DIR = Path("/var/lib/sunshine-virt-display")
      DATA_DIR.mkdir(parents=True, exist_ok=True)' \
              --replace-fail 'SCRIPT_DIR / "custom_edid.bin"' 'DATA_DIR / "custom_edid.bin"' \
              --replace-fail 'SCRIPT_DIR / "virt_display.state"' 'DATA_DIR / "virt_display.state"'

            substituteInPlace src/drm/bindings.py \
              --replace-fail 'name = ctypes.util.find_library("drm")' \
                             'name = ctypes.util.find_library("drm") or "${libdrm}/lib/libdrm.so.2"'
    '';

    installPhase = ''
      runHook preInstall

      mkdir -p $out/share/sunshine-virt-display $out/bin
      cp -r src $out/share/sunshine-virt-display/

      makeWrapper ${pythonEnv}/bin/python3 $out/bin/sunshineVD \
        --add-flags "$out/share/sunshine-virt-display/src/daemon/daemon.py" \
        --prefix PATH : ${lib.makeBinPath [coreutils bash]}

      runHook postInstall
    '';

    passthru.updateScript = nix-update-script {};

    meta = {
      description = "Virtual display manager for Sunshine streaming";
      homepage = "https://github.com/frostplexx/sunshine_virt_display";
      license = lib.licenses.mit;
      platforms = lib.platforms.linux;
      mainProgram = "sunshineVD";
    };
  }
