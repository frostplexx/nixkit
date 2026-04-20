{...} @ args:
import ./packages {
  pkgs = args.pkgs or (import <nixpkgs> {});
  system = args.system or builtins.currentSystem;
}
