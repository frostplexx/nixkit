{
  lib,
  vimUtils,
  fetchFromGitHub,
  nix-update-script,
}: let
  rev = "f897910d0dc1b919be88ab1cd35445bb53d70390";
  src = fetchFromGitHub {
    owner = "ThePrimeagen";
    repo = "99";
    inherit rev;
    hash = "sha256-KiFdTCl9Cje+AIkl21UzKRYCgooKKrX0GIlX/fyMX5U=";
  };
  version = "0-unstable-2026-06-10";
in
  vimUtils.buildVimPlugin {
    pname = "nvim-99";
    inherit version src;

    # Extension modules require optional plugins (telescope, fzf-lua)
    # that are not dependencies of this package
    nvimSkipModules = [
      "99.extensions.telescope"
      "99.extensions.fzf_lua"
      # Fails to load outside a running LSP session
      "99.editor.lsp"
    ];

    passthru.updateScript = nix-update-script {extraArgs = ["--version=branch"];};

    meta = with lib; {
      description = "Agentic AI workflow for Neovim that augments the programmer instead of replacing them";
      homepage = "https://github.com/ThePrimeagen/99";
      license = licenses.mit;
    };
  }
