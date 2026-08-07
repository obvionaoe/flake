{lib}: dir: pkgs:
if builtins.pathExists dir
then let
  entries = builtins.readDir dir;
  # a package dir is any directory of `dir` containing a default.nix — this
  # excludes pkgs/CLAUDE.md and lets pkgs-update's own dir be discovered the
  # same way as any other self-rolled derivation
  isPkgDir = name: type:
    type == "directory" && builtins.pathExists (dir + "/${name}/default.nix");
  names = builtins.attrNames (lib.filterAttrs isPkgDir entries);
in
  lib.genAttrs names (name: pkgs.callPackage (dir + "/${name}") {})
else {}
