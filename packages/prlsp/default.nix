{
  lib,
  buildGoModule,
  vimUtils,
  fetchFromGitHub,
  nix-update-script,
}: let
  src = fetchFromGitHub {
    owner = "toziegler";
    repo = "prlsp";
    rev = "v${version}";
    hash = "sha256-DzyEWnLXN1HOVVRv1h5blnQnnEcAY17O+LBUYKzTx+E=";
  };
  version = "0.1.0";
in {
  # The Go LSP server binary
  prlsp = buildGoModule {
    pname = "prlsp";
    inherit version src;
    sourceRoot = "source/go";
    postPatch = ''
      substituteInPlace go.mod --replace-fail 'go 1.25.7' 'go 1.24'
    '';
    vendorHash = null;
    passthru.updateScript = nix-update-script {};

    meta = with lib; {
      description = "LSP server that surfaces GitHub PR review comments as editor diagnostics";
      homepage = "https://github.com/toziegler/prlsp";
      license = licenses.mit;
      mainProgram = "prlsp";
    };
  };

  # The Neovim plugin (Lua helpers, commands, keymaps)
  prlsp-nvim = vimUtils.buildVimPlugin {
    pname = "prlsp-nvim";
    inherit version src;
    meta = with lib; {
      description = "Neovim plugin for prlsp — view and reply to GitHub PR review comments via LSP";
      homepage = "https://github.com/toziegler/prlsp";
    };
  };
}
