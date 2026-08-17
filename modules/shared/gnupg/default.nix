{
  config,
  lib,
  pkgs,
  user,
  ...
}: let
  cfg = config.modules.gnupg;
in {
  options.modules.gnupg.enable = lib.mkEnableOption "GnuPG";

  config = lib.mkIf cfg.enable {
    home-manager.users.${user} = {
      programs.gpg.enable = true;
      services.gpg-agent = {
        enable = true;
        pinentry.package =
          if pkgs.stdenv.isDarwin
          then pkgs.pinentry_mac
          else pkgs.pinentry-curses;
      };
    };
  };
}
