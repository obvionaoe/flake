{
  config,
  lib,
  pkgs,
  user,
  ...
}: {
  options.modules.decant.enable = lib.mkEnableOption "decant (Claude Code/Codex session analysis)";

  config = lib.mkIf config.modules.decant.enable {
    home-manager.users.${user}.home.packages = [pkgs.local.decant];
  };
}
