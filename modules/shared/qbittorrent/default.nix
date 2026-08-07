{
  config,
  lib,
  pkgs,
  user,
  ...
}: let
  cfg = config.modules.qbittorrent;
in {
  # A Qt app, not Electron — builds natively and reliably via nixpkgs, so
  # this is one of the few GUI apps where nixpkgs is the smoother path
  # rather than a Homebrew cask.
  options.modules.qbittorrent.enable = lib.mkEnableOption "qBittorrent";

  config = lib.mkIf cfg.enable {
    home-manager.users.${user}.home.packages = [pkgs.qbittorrent];
  };
}
