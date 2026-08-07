{
  config,
  lib,
  pkgs,
  user,
  ...
}: {
  options.modules.soloterm.enable = lib.mkEnableOption "SoloTerm (Solo)";

  config = lib.mkIf config.modules.soloterm.enable {
    home-manager.users.${user}.home.packages = [pkgs.local.soloterm];
  };
}
