{
  config,
  lib,
  ...
}: {
  options.modules.plex.enable = lib.mkEnableOption "Plex desktop client";

  config = lib.mkIf config.modules.plex.enable {
    homebrew.casks = ["plex"];
  };
}
