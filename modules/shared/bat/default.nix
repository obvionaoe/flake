{
  config,
  lib,
  user,
  ...
}: let
  cfg = config.modules.bat;
in {
  options.modules.bat.enable = lib.mkEnableOption "bat (modern cat replacement)";

  config = lib.mkIf cfg.enable {
    home-manager.users.${user} = {
      programs.bat.enable = true;

      home.shellAliases = {
        cat = "bat";
      };
    };
  };
}
