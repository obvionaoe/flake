{
  config,
  lib,
  pkgs,
  user,
  ...
}: let
  cfg = config.modules.asana-cli;
in {
  options.modules.asana-cli.enable = lib.mkEnableOption "asana-api-cli (Asana CLI wrapping the full official Python SDK)";

  config = lib.mkIf cfg.enable {
    home-manager.users.${user}.home.packages = [pkgs.local.asana-api-cli];
  };
}
