{
  config,
  lib,
  pkgs,
  user,
  ...
}: let
  cfg = config.modules.auth0-cli;
in {
  options.modules.auth0-cli.enable = lib.mkEnableOption "Auth0 CLI";

  config = lib.mkIf cfg.enable {
    home-manager.users.${user}.home.packages = [pkgs.unstable.auth0-cli];
  };
}
