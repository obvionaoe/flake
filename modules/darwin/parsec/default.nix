{
  config,
  lib,
  ...
}: {
  options.modules.parsec.enable = lib.mkEnableOption "Parsec";

  config = lib.mkIf config.modules.parsec.enable {
    homebrew.casks = ["parsec"];
  };
}
