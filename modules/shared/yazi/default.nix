{
  config,
  lib,
  pkgs,
  user,
  ...
}: let
  cfg = config.modules.yazi;
in {
  options.modules.yazi.enable = lib.mkEnableOption "yazi (terminal file manager)";

  config = lib.mkIf cfg.enable {
    home-manager.users.${user}.programs.yazi = {
      enable = true;

      package = pkgs.unstable.yazi;

      enableZshIntegration = config.modules.zsh.enable;
    };
  };
}
