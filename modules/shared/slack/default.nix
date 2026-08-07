{
  config,
  lib,
  pkgs,
  user,
  ...
}: let
  cfg = config.modules.slack;
in {
  options.modules.slack.enable = lib.mkEnableOption "Slack";

  config = lib.mkIf cfg.enable {
    home-manager.users.${user}.home.packages = [pkgs.unstable.slack];
  };
}
