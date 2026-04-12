{
  nixpkgs ? <nixpkgs>,
  nixkit ? {},
  system ? builtins.currentSystem,
}: let
  pkgs = import nixpkgs {inherit system;};

  nixkitVersion = builtins.fromJSON (builtins.readFile ./version.json);

  isLinux = system == "x86_64-linux" || system == "aarch64-linux";
  isDarwin = system == "x86_64-darwin" || system == "aarch64-darwin";

  nixkitPackages = import ./packages {inherit pkgs system;};

  baseModule = {
    options = {
      home = pkgs.lib.mkOption {
        type = pkgs.lib.types.attrs;
        description = "Home manager configuration";
      };
      environment.systemPackages = pkgs.lib.mkOption {
        type = pkgs.lib.types.listOf pkgs.lib.types.package;
        description = "Packages to install into the system environment";
      };
      services.sunshine.enable = pkgs.lib.mkOption {
        type = pkgs.lib.types.bool;
        description = "Enable sunshine service";
        default = false;
      };
    };
    config = {};
  };

  nixosModules =
    if isLinux
    then [(import ./modules/shared {})]
    else [];
  darwinModules = [];

  scrubbedEval = pkgs.lib.evalModules {
    modules = [baseModule] ++ nixosModules ++ darwinModules;
    specialArgs = {pkgs = pkgs // nixkitPackages;};
  };
  options = scrubbedEval.options;

  optionsDoc = pkgs.buildPackages.nixosOptionsDoc {
    inherit options;
    transformOptions = opt: opt;
  };

  optionsJSON =
    pkgs.runCommand "options.json" {
      meta.description = "List of nixkit options in JSON format";
    } ''
      mkdir -p $out/{share/doc,nix-support}
      cp -a ${optionsDoc.optionsJSON}/share/doc/nixos $out/share/doc/nixkit
      substitute \
        ${optionsDoc.optionsJSON}/nix-support/hydra-build-products \
        $out/nix-support/hydra-build-products \
        --replace-fail \
          '${optionsDoc.optionsJSON}/share/doc/nixos' \
          "$out/share/doc/nixkit"
    '';

  manualHTML =
    pkgs.runCommand "nixkit-manual-html" {
      nativeBuildInputs = [pkgs.buildPackages.nixos-render-docs];
      styles = pkgs.lib.sourceFilesBySuffices (pkgs.path + "/doc") [".css"];
      meta.description = "The Nixkit manual in HTML format";
      allowedReferences = ["out"];
    } ''
      dst=$out/share/doc/nixkit
      mkdir -p $dst

      cp $styles/style.css $dst
      cp -r ${pkgs.documentation-highlighter} $dst/highlightjs

      substitute ${./docs/manual/manual.md} manual.md \
        --replace-fail '@NIXKIT_VERSION@' "${nixkitVersion.release}" \
        --replace-fail '@NIXKIT_OPTIONS_JSON@' ${optionsJSON}/share/doc/nixkit/options.json

      nixos-render-docs -j $NIX_BUILD_CORES manual html \
        --manpage-urls ${pkgs.writeText "manpage-urls.json" "{}"} \
        --revision "${nixkit.rev or "main"}" \
        --generator "nixos-render-docs ${pkgs.lib.version}" \
        --stylesheet style.css \
        --stylesheet highlightjs/mono-blue.css \
        --script ./highlightjs/highlight.pack.js \
        --script ./highlightjs/loader.js \
        --toc-depth 1 \
        --chunk-toc-depth 1 \
        ./manual.md \
        $dst/index.html

      mkdir -p $out/nix-support
      echo "nix-build out $out" >> $out/nix-support/hydra-build-products
      echo "doc manual $dst" >> $out/nix-support/hydra-build-products
    '';

  manpages =
    pkgs.runCommand "nixkit-manpages" {
      nativeBuildInputs = [pkgs.buildPackages.nixos-render-docs];
      allowedReferences = ["out"];
    } ''
      mkdir -p $out/share/man/man5
      nixos-render-docs -j $NIX_BUILD_CORES options manpage \
        --revision "${nixkit.rev or "main"}" \
        ${optionsJSON}/share/doc/nixkit/options.json \
        $out/share/man/man5/configuration.nix.5

      sed -i -e '
        /^\.TH / s|NixOS|nixkit|g
        /^\.SH "NAME"$/ { N; s|NixOS|nixkit|g }
        /^\.SH "DESCRIPTION"$/ { N; N; s|/etc/nixos/configuration|configuration|g; s|NixOS|nixkit|g; s|nixos|nixkit|g }
      ' $out/share/man/man5/configuration.nix.5
    '';
in {
  docs = {
    inherit manualHTML manpages optionsJSON;
  };
}
