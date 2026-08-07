{
  config,
  lib,
  pkgs,
  user,
  home-manager,
  ...
}: let
  cfg = config.modules.rtk;
in {
  options.modules.rtk.enable = lib.mkEnableOption "rtk (LLM token-saving CLI proxy)";

  config = lib.mkIf cfg.enable {
    home-manager.users.${user} = {
      home.packages = [pkgs.rtk];

      home.activation.rtkInit = home-manager.lib.hm.dag.entryAfter ["writeBoundary"] ''
        $DRY_RUN_CMD ${pkgs.rtk}/bin/rtk init -g --auto-patch
      '';
    };
  };
}
