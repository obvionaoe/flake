{
  config,
  lib,
  pkgs,
  user,
  aps,
  ...
}: {
  options.modules.aps.enable = lib.mkEnableOption "aps (AWS profile switcher)";

  config = lib.mkIf config.modules.aps.enable {
    home-manager.users.${user}.home.packages = [aps.packages.${pkgs.stdenv.hostPlatform.system}.default];
  };
}
