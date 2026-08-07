{
  config,
  lib,
  pkgs,
  user,
  ...
}: {
  options.modules.pkgs-update.enable = lib.mkEnableOption "pkgs-update (refreshes self-rolled pkgs/<name> derivations)";

  config = lib.mkIf config.modules.pkgs-update.enable {
    home-manager.users.${user}.home.packages = [pkgs.local.pkgs-update];
  };
}
