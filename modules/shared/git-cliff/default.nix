{
  config,
  lib,
  user,
  ...
}: let
  cfg = config.modules.git-cliff;
in {
  options.modules.git-cliff.enable = lib.mkEnableOption "git-cliff (changelog generator)";

  config = lib.mkIf cfg.enable {
    home-manager.users.${user}.programs.git-cliff = {
      enable = true;

      settings = {
        header = "Changelog";
        trim = true;
      };
    };
  };
}
