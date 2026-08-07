{
  config,
  lib,
  pkgs,
  user,
  ...
}: let
  cfg = config.modules.nixd;
in {
  options.modules.nixd.enable = lib.mkEnableOption "nixd (Nix language server)";

  config = lib.mkIf cfg.enable {
    home-manager.users.${user}.home.packages = [pkgs.nixd];
  };
}
