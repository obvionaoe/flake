{
  config,
  lib,
  pkgs,
  user,
  ...
}: let
  cfg = config.modules.discord;
in {
  options.modules.discord.enable = lib.mkEnableOption "Discord";

  config = lib.mkIf cfg.enable {
    home-manager.users.${user}.home.packages = [pkgs.unstable.discord];
  };
}
