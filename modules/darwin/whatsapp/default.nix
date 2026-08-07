{
  config,
  lib,
  pkgs,
  user,
  ...
}: {
  options.modules.whatsapp.enable = lib.mkEnableOption "WhatsApp desktop client";

  config = lib.mkIf config.modules.whatsapp.enable {
    home-manager.users.${user}.home.packages = [pkgs.whatsapp-for-mac];
  };
}
