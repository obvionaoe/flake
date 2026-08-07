{
  config,
  lib,
  ...
}: {
  options.modules.steam.enable = lib.mkEnableOption "Steam";

  config = lib.mkIf config.modules.steam.enable {
    homebrew.casks = ["steam"];
  };
}
