{
  lib,
  stdenv,
  fetchFromGitHub,
  makeWrapper,
  python3,
  bash,
  coreutils,
}:
stdenv.mkDerivation {
  pname = "sunshine-virt-display";
  version = "1.1.0";

  src = fetchFromGitHub {
    owner = "frostplexx";
    repo = "sunshine_virt_display";
    rev = "v1.1.0";
    sha256 = "17sjk8f4xhdgmsanr3pkb865v60v042lwsdwh5ghrigzdiddgbcv";
  };

  nativeBuildInputs = [makeWrapper];
  buildInputs = [
    python3
    bash
  ];

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
