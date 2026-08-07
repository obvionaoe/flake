{
  config,
  lib,
  user,
  ...
}: let
  cfg = config.modules.direnv;
in {
  options.modules.direnv.enable = lib.mkEnableOption "direnv";

  config = lib.mkIf cfg.enable {
    home-manager.users.${user}.programs.direnv = {
      enable = true;
      nix-direnv.enable = true;
    };
  };
}
