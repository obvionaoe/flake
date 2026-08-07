{
  config,
  lib,
  pkgs,
  user,
  ...
}: let
  cfg = config.modules.obsidian;
in {
  options.modules.obsidian.enable = lib.mkEnableOption "Obsidian";

  config = lib.mkIf cfg.enable {
    home-manager.users.${user}.home.packages = [pkgs.obsidian];
  };
}
