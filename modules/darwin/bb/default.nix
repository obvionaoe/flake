{
  config,
  lib,
  pkgs,
  user,
  ...
}: {
  options.modules.bb.enable = lib.mkEnableOption "bb (getbb.app)";

  config = lib.mkIf config.modules.bb.enable {
    home-manager.users.${user}.home.packages = [pkgs.local.bb];
  };
}
