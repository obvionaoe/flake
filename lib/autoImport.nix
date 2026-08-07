{lib}: dir:
if builtins.pathExists dir
then let
  entries = builtins.readDir dir;
  isModule = name: type:
    type == "directory" || (type == "regular" && lib.hasSuffix ".nix" name);
  names = builtins.attrNames (lib.filterAttrs isModule entries);
in
  map (name: dir + "/${name}") names
else []
