{
  config,
  lib,
  user,
  ...
}: let
  cfg = config.modules.nodejs;
in {
  options.modules.nodejs.enable = lib.mkEnableOption "Node.js";

  config = lib.mkIf cfg.enable {
    home-manager.users.${user}.programs.npm.enable = true;
  };
}
