{
  config,
  lib,
  pkgs,
  user,
  ...
}: let
  cfg = config.modules.doppler;
in {
  options.modules.doppler.enable = lib.mkEnableOption "Doppler secrets manager CLI";

  config = lib.mkIf cfg.enable {
    home-manager.users.${user}.home.packages = [pkgs.doppler];
  };
}
