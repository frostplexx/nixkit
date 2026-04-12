{
  description = "Various internal modules and packages for NixOS and nix-darwin";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    flake-parts.url = "github:hercules-ci/flake-parts";
  };

  outputs = inputs @ {flake-parts, ...}:
    flake-parts.lib.mkFlake {inherit inputs;} {
      systems = [
        "x86_64-linux"
        "aarch64-linux"
        "x86_64-darwin"
        "aarch64-darwin"
      ];

      perSystem = {
        system,
        pkgs,
        ...
      }: let
        isLinux = system == "x86_64-linux" || system == "aarch64-linux";

        nixkitPackages = import ./packages {inherit pkgs system;};

        allModules =
          [(import ./modules/home {})]
          ++ (
            if isLinux
            then [(import ./modules/shared {})]
            else []
          );

        moduleEval = pkgs.lib.evalModules {
          modules =
            allModules
            ++ [
              {
                options = {
                  home = pkgs.lib.mkOption {
                    type = pkgs.lib.types.attrs;
                    description = "";
                  };
                };
                config = {
                  home.username = pkgs.lib.mkDefault "";
                  _module.check = false;
                };
              }
            ];
          specialArgs = {pkgs = pkgs // nixkitPackages;};
        };

        allOptions = pkgs.lib.removeAttrs moduleEval.options ["home" "_module"];

        nixkitVersion = builtins.fromJSON (builtins.readFile ./version.json);

        packagesTable =
          "| Package | Description | Platforms |\n| ------- | ----------- | --------- |\n"
          + (pkgs.lib.concatStringsSep "\n" (pkgs.lib.mapAttrsToList (
            name: pkg: let
              desc = pkg.meta.description or "Package";
              plats = pkg.meta.platforms or [pkgs.stdenv.hostPlatform.system];
              platStr = pkgs.lib.concatStringsSep ", " (
                pkgs.lib.map (
                  p:
                    if p == "x86_64-linux"
                    then "Linux"
                    else if p == "aarch64-linux"
                    then "Linux (ARM)"
                    else if p == "x86_64-darwin"
                    then "macOS"
                    else if p == "aarch64-darwin"
                    then "macOS (ARM)"
                    else p
                )
                plats
              );
            in "| ${name} | ${desc} | ${platStr} |"
          ) (pkgs.lib.filterAttrs (n: p: pkgs.lib.isDerivation p && p ? meta && p.meta ? description) nixkitPackages)));

        optionsDoc = pkgs.buildPackages.nixosOptionsDoc {options = allOptions;};

        optionsJSON =
          pkgs.runCommand "options.json" {
            meta.description = "List of nixkit options in JSON format";
          } ''
            mkdir -p $out/{share/doc,nix-support}
            cp -a ${optionsDoc.optionsJSON}/share/doc/nixos $out/share/doc/nixkit
            substitute ${optionsDoc.optionsJSON}/nix-support/hydra-build-products \
              $out/nix-support/hydra-build-products \
              --replace-fail '${optionsDoc.optionsJSON}/share/doc/nixos' "$out/share/doc/nixkit"
          '';

        manualSrc = pkgs.runCommand "manual-src" {} ''
          mkdir -p $out
          substitute ${./docs/manual/manual.md} $out/manual.md \
            --replace-fail '@NIXKIT_VERSION@' "${nixkitVersion.release}" \
            --replace-fail '@NIXKIT_OPTIONS_JSON@' ${optionsJSON}/share/doc/nixkit/options.json
        '';

        manualHTML = let
          formatPlatform = p:
            if p == "x86_64-linux"
            then "Linux"
            else if p == "aarch64-linux"
            then "Linux (ARM)"
            else if p == "x86_64-darwin"
            then "macOS"
            else if p == "aarch64-darwin"
            then "macOS (ARM)"
            else null;

          packageRows = pkgs.lib.attrValues (
            pkgs.lib.mapAttrs (
              name: pkg: let
                desc = pkg.meta.description or "Package";
                plats = pkg.meta.platforms or [pkgs.stdenv.hostPlatform.system];
                relevantPlats = pkgs.lib.filter (p: formatPlatform p != null) plats;
                platStr =
                  if relevantPlats == []
                  then "All"
                  else pkgs.lib.concatStringsSep ", " (pkgs.lib.map formatPlatform relevantPlats);
              in
                if pkgs.lib.isDerivation pkg && pkg ? meta && pkg.meta ? description
                then "    <tr><td>${name}</td><td>${desc}</td><td>${platStr}</td></tr>"
                else null
            )
            nixkitPackages
          );

          packagesTableText = pkgs.lib.concatStringsSep "\n" packageRows;

          packagesTableHTML = pkgs.writeText "packages-table.html" ''
            <h2>Packages</h2>
            <p>The following packages are provided by nixkit:</p>
            <table>
              <thead>
                <tr><th>Package</th><th>Description</th><th>Platforms</th></tr>
              </thead>
              <tbody>
            ${packagesTableText}
              </tbody>
            </table>

            <h2>Requirements</h2>
            <ul>
              <li>Nix with flakes enabled</li>
              <li>For Home Manager modules: <a href="https://github.com/nix-community/home-manager">Home Manager</a></li>
              <li>For NixOS modules: NixOS system</li>
              <li>For Darwin modules: <a href="https://github.com/LnL7/nix-darwin">nix-darwin</a></li>
            </ul>
          '';
        in
          pkgs.runCommand "nixkit-manual-html" {
            nativeBuildInputs = [pkgs.buildPackages.nixos-render-docs];
            styles = pkgs.lib.sourceFilesBySuffices (pkgs.path + "/doc") [".css"];
            meta.description = "The Nixkit manual in HTML format";
            allowedReferences = ["out" packagesTableHTML];
          } ''
                                    dst=$out/share/doc/nixkit
                                    mkdir -p $dst
                                    cp $styles/style.css $dst
                                    cp -r ${pkgs.documentation-highlighter} $dst/highlightjs

                                    nixos-render-docs -j $NIX_BUILD_CORES manual html \
                                      --manpage-urls ${pkgs.writeText "manpage-urls.json" "{}"} \
                                      --revision "main" \
                                      --generator "nixos-render-docs ${pkgs.lib.version}" \
                                      --stylesheet style.css \
                                      --stylesheet highlightjs/mono-blue.css \
                                      --script ./highlightjs/highlight.pack.js \
                                      --script ./highlightjs/loader.js \
                                      --toc-depth 1 \
                                      --chunk-toc-depth 1 \
                                      ${manualSrc}/manual.md \
                                      $dst/index.html

            sed -i '/<div><h2 class="subtitle">/r ${packagesTableHTML}' $dst/index.html

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
              --revision "main" \
              ${optionsJSON}/share/doc/nixkit/options.json \
              $out/share/man/man5/configuration.nix.5

            sed -i -e '
              /^\.TH / s|NixOS|nixkit|g
              /^\.SH "NAME"$/ { N; s|NixOS|nixkit|g }
              /^\.SH "DESCRIPTION"$/ { N; N; s|/etc/nixos/configuration|configuration|g; s|NixOS|nixkit|g; s|nixos|nixkit|g }
            ' $out/share/man/man5/configuration.nix.5
          '';
      in {
        packages =
          pkgs.lib.filterAttrs (
            _: p:
              pkgs.lib.isDerivation p
              && pkgs.lib.meta.availableOn pkgs.stdenv.hostPlatform p
              && !(p.meta.unsupported or false)
          )
          nixkitPackages
          // {
            inherit manualHTML manpages optionsJSON;
            website = let
              manualDir =
                pkgs.runCommand "manual-doc" {
                  nativeBuildInputs = [pkgs.buildPackages.nixos-render-docs];
                  allowedReferences = ["out" manualHTML];
                } ''
                  mkdir -p $out
                  cp -r ${manualHTML}/share/doc/nixkit/* $out/
                  cd $out
                  sed -i 's|href="style.css"|href="./style.css"|g' index.html
                  sed -i 's|href="highlightjs/|href="./highlightjs/|g' index.html
                  sed -i 's|src="highlightjs/|src="./highlightjs/|g' index.html
                '';
            in
              pkgs.linkFarm "nixkit-website" {
                "index.html" = "${manualDir}/index.html";
                "style.css" = "${manualDir}/style.css";
                "highlightjs" = "${manualDir}/highlightjs";
              };
          };

        devShells.default = pkgs.mkShell {
          packages = with pkgs; [nix-update git python3];
          shellHook = ''
            echo "=> nixkit development environment ready!"
          '';
        };
      };

      flake = {
        overlays.default = import ./overlay.nix;
        homeModules.default = import ./modules/home;
        nixosModules.default = {
          nixpkgs.overlays = [inputs.self.overlays.default];
          imports = [./modules/nixos];
        };
        darwinModules.default = {
          nixpkgs.overlays = [inputs.self.overlays.default];
          imports = [./modules/darwin];
        };
      };
    };
}
