{
  config,
  lib,
  pkgs,
  user,
  ...
}: let
  cfg = config.modules.linear;
in {
  options.modules.linear.enable = lib.mkEnableOption "Linear";

  config = lib.mkIf cfg.enable {
    # nixpkgs' `linear` is darwin-only, hence modules/darwin.
    home-manager.users.${user}.home.packages = [pkgs.unstable.linear];
  };
}
