{
  config,
  lib,
  user,
  ...
}: let
  cfg = config.modules.fastfetch;
in {
  options.modules.fastfetch.enable = lib.mkEnableOption "fastfetch (system info)";

  config = lib.mkIf cfg.enable {
    home-manager.users.${user}.programs.fastfetch.enable = true;
  };
}
