{
  lib,
  stdenv,
  fetchFromGitHub,
  makeWrapper,
  python3,
  bash,
  coreutils,
}: let
  version = "1.1.0";
in
  stdenv.mkDerivation {
    pname = "sunshine-virt-display";
    inherit version;

    src = fetchFromGitHub {
      owner = "frostplexx";
      repo = "sunshine_virt_display";
      rev = "v${version}";
      sha256 = "17sjk8f4xhdgmsanr3pkb865v60v042lwsdwh5ghrigzdiddgbcv";
    };

    nativeBuildInputs = [makeWrapper];
    buildInputs = [
      python3
      bash
    ];

    postPatch = ''
          substituteInPlace virt_display.sh \
            --replace-fail 'sudo python3 "$PYTHON_SCRIPT"' \
                           'sudo ${python3}/bin/python3 "$PYTHON_SCRIPT"'
          substituteInPlace main.py \
            --replace-fail 'SCRIPT_DIR = Path(__file__).parent.absolute()' \
                           'SCRIPT_DIR = Path(__file__).parent.absolute()
      DATA_DIR = Path("/var/lib/sunshine-virt-display")
      DATA_DIR.mkdir(parents=True, exist_ok=True)' \
            --replace-fail 'SCRIPT_DIR / "custom_edid.bin"' 'DATA_DIR / "custom_edid.bin"' \
            --replace-fail 'SCRIPT_DIR / "virt_display.state"' 'DATA_DIR / "virt_display.state"'
    '';

    installPhase = ''
      mkdir -p $out/share/sunshine-virt-display $out/bin
      cp -r * $out/share/sunshine-virt-display/

      wrapProgram $out/share/sunshine-virt-display/virt_display.sh \
        --prefix PATH : ${lib.makeBinPath [python3 bash coreutils]} \
        --suffix PATH : /run/wrappers/bin

      ln -s $out/share/sunshine-virt-display/virt_display.sh $out/bin/virt_display.sh
    '';

    meta = {
      description = "Virtual display manager for Sunshine streaming";
      homepage = "https://github.com/frostplexx/sunshine_virt_display";
      license = lib.licenses.mit;
      platforms = lib.platforms.linux;
      mainProgram = "virt_display.sh";
    };
  }
