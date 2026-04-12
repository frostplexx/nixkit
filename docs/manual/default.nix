{
  pkgs,
  options,
  config,
  version,
  revision,
  nixpkgsRevision,
  extraSources ? [],
  prefix ? ../..,
}:
with pkgs; let
  lib = pkgs.lib;

  gitHubDeclaration = user: repo: ref: subpath:
  # Default to `master` if we don't know what revision the system
  # configuration is using (custom nixpkgs, etc.).
  let
    urlRef =
      if ref != null
      then ref
      else "main";
  in {
    url = "https://github.com/${user}/${repo}/blob/${urlRef}/${subpath}";
    name = "<${repo}/${subpath}>";
  };

  optionsDoc = buildPackages.nixosOptionsDoc {
    inherit options;
    transformOptions = opt:
      opt
      // {
        # Clean up declaration sites to not refer to the nixkit source tree.
        # TODO: handle `extraSources`? (it's not set anywhere)
        declarations =
          map
          (decl:
            if lib.hasPrefix (toString prefix) (toString decl)
            then
              gitHubDeclaration "frostplexx" "nixkit" revision
              (lib.removePrefix "/"
                (lib.removePrefix (toString prefix) (toString decl)))
            # TODO: handle this in a better way (may require upstream
            # changes to nixpkgs)
            else if decl == "lib/modules.nix"
            then gitHubDeclaration "NixOS" "nixpkgs" nixpkgsRevision decl
            else decl)
          opt.declarations;
      };
  };
in rec {
  # TODO: Use `optionsDoc.optionsJSON` directly once upstream
  # `nixosOptionsDoc` is more customizable.
  optionsJSON =
    runCommand "options.json"
    {meta.description = "List of nixkit options in JSON format";}
    ''
      mkdir -p $out/{share/doc,nix-support}
      cp -a ${optionsDoc.optionsJSON}/share/doc/nixos $out/share/doc/nixos
      substitute \
        ${optionsDoc.optionsJSON}/nix-support/hydra-build-products \
        $out/nix-support/hydra-build-products \
        --replace-fail \
          '${optionsDoc.optionsJSON}/share/doc/nixos' \
          "$out/share/doc/nixos"
    '';

  # Generate the nixkit manual.
  manualHTML =
    runCommand "nixkit-manual-html"
    {
      nativeBuildInputs = [buildPackages.nixos-render-docs];
      styles = lib.sourceFilesBySuffices (pkgs.path + "/doc") [".css"];
      meta.description = "The Nixkit manual in HTML format";
      allowedReferences = ["out"];
    }
    ''
      # Generate the HTML manual.
      dst=$out/share/doc/nixkit
      mkdir -p $dst

      cp $styles/style.css $dst
      cp -r ${pkgs.documentation-highlighter} $dst/highlightjs

      substitute ${./manual.md} manual.md \
        --replace-fail '@NIXKIT_VERSION@' "${version}" \
        --replace-fail \
          '@NIXKIT_OPTIONS_JSON@' \
          ${optionsJSON}/share/doc/nixos/options.json

      # Pass --redirects option if nixos-render-docs supports it
      if nixos-render-docs manual html --help | grep --silent -E '^\s+--redirects\s'; then
        redirects_opt="--redirects ${./redirects.json}"
      fi

      # TODO: --manpage-urls?
      nixos-render-docs -j $NIX_BUILD_CORES manual html \
        --manpage-urls ${pkgs.writeText "manpage-urls.json" "{}"} \
        --revision ${lib.escapeShellArg revision} \
        --generator "nixos-render-docs ${lib.version}" \
        $redirects_opt \
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

  # Index page of the nixkit manual.
  manualHTMLIndex = "${manualHTML}/share/doc/nixkit/index.html";

  manualEpub = builtins.throw "The nixkit EPUB manual has been removed.";

  # Generate the nixkit manpages.
  manpages =
    runCommand "nixkit-manpages"
    {
      nativeBuildInputs = [buildPackages.nixos-render-docs];
      allowedReferences = ["out"];
    }
    ''
      # Generate manpages.
      mkdir -p $out/share/man/man5
      nixos-render-docs -j $NIX_BUILD_CORES options manpage \
        --revision ${lib.escapeShellArg revision} \
        ${optionsJSON}/share/doc/nixos/options.json \
        $out/share/man/man5/configuration.nix.5

      # TODO: get these parameterized in upstream nixos-render-docs
      sed -i -e '
        /^\.TH / s|NixOS|nixkit|g

        /^\.SH "NAME"$/ {
          N
          s|NixOS|nixkit|g
        }

        /^\.SH "DESCRIPTION"$/ {
          N; N
          s|/etc/nixos/configuration|configuration|g
          s|NixOS|nixkit|g
          s|nixos|nixkit|g
        }

        /\.SH "AUTHORS"$/ {
          N; N
          s|Eelco Dolstra and the Nixpkgs/NixOS contributors|Daiderd Jordan and the nixkit contributors|g
        }
      ' $out/share/man/man5/configuration.nix.5
    '';
}
