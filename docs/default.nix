{
  pkgs,
  lib ? pkgs.lib,
}: let
  scrubDerivations = namePrefix: pkgSet:
    builtins.mapAttrs (
      name: value: let
        wholeName = "${namePrefix}.${name}";
      in
        if builtins.isAttrs value
        then
          scrubDerivations wholeName value
          // lib.optionalAttrs (lib.isDerivation value) {
            drvPath = value.drvPath;
            outPath = "\${${wholeName}}";
          }
        else value
    )
    pkgSet;

  scrubbedPkgs = scrubDerivations "pkgs" pkgs;

  modules = [
    (import ../modules/shared {
      pkgs = scrubbedPkgs;
      lib = lib;
    })
    (import ../modules/nixos {
      pkgs = scrubbedPkgs;
      lib = lib;
    })
    (import ../modules/darwin {
      pkgs = scrubbedPkgs;
      lib = lib;
    })
    (import ../modules/home {
      pkgs = scrubbedPkgs;
      lib = lib;
    })
    {
      _module.check = false;
      _module.args.pkgs = lib.mkForce scrubbedPkgs;
    }
  ];

  evalResult = lib.evalModules {
    modules = modules;
  };

  optionsDoc = pkgs.nixosOptionsDoc {
    variablelistId = "nixkit-options";
    warningsAreErrors = false;
    inherit (evalResult) options;
  };
in {
  options.json =
    pkgs.runCommand "options.json" {
      meta.description = "List of nixkit options in JSON format";
    } ''
      mkdir -p $out/share/doc/nixkit
      cp -r ${optionsDoc.optionsJSON}/share/doc/nixos/* $out/share/doc/nixkit/
    '';

  manPages =
    pkgs.runCommand "nixkit-reference-manpage" {
      nativeBuildInputs = [
        pkgs.buildPackages.installShellFiles
        pkgs.nixos-render-docs
      ];
      allowedReferences = ["out"];
    } ''
      mkdir -p $out/share/man/{man5,man1}
      cp ${./man/nixkit.1} $out/share/man/man1/nixkit.1
      nixos-render-docs -j $NIX_BUILD_CORES options manpage \
        --revision "unstable" \
        --header ${./man/header.5} \
        --footer ${./man/footer.5} \
        ${optionsDoc.optionsJSON}/share/doc/nixos/options.json \
        $out/share/man/man5/nixkit.5
    '';
}
