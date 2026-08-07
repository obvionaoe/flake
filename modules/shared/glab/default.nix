{
  config,
  lib,
  pkgs,
  user,
  ...
}: let
  cfg = config.modules.glab;
in {
  options.modules.glab.enable = lib.mkEnableOption "glab (GitLab CLI)";

  config = lib.mkIf cfg.enable {
    home-manager.users.${user}.home.packages = [pkgs.glab];
  };
}
