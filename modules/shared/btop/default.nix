{
  config,
  lib,
  user,
  ...
}: let
  cfg = config.modules.btop;
in {
  options.modules.btop.enable = lib.mkEnableOption "btop (resource monitor)";

  config = lib.mkIf cfg.enable {
    home-manager.users.${user}.programs.btop.enable = true;
  };
}
