{
  config,
  lib,
  pkgs,
  user,
  ...
}: let
  cfg = config.modules.cli-misc;
in {
  # Grab-bag for standalone CLI utilities that don't need any config of their
  # own (no `programs.<name>` module, no dotfiles, just a binary). If one of
  # these ever needs real configuration, pull it out into its own module.
  options.modules.cli-misc.enable = lib.mkEnableOption "misc CLI utilities (gum, ncdu, tree, yt-dlp, pandoc, envsubst, xdg-ninja, coreutils)";

  config = lib.mkIf cfg.enable {
    home-manager.users.${user}.home.packages = with pkgs; [
      unstable.gum
      ncdu
      tree
      yt-dlp
      pandoc
      envsubst
      xdg-ninja
      coreutils
    ];
  };
}
