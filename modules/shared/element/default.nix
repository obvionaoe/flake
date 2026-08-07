{
  config,
  lib,
  pkgs,
  user,
  ...
}: let
  cfg = config.modules.element;
in {
  options.modules.element.enable = lib.mkEnableOption "Element (Matrix client)";

  config = lib.mkIf cfg.enable {
    home-manager.users.${user}.home.packages = [pkgs.unstable.element-desktop];
  };
}
