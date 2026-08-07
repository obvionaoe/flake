{
  config,
  lib,
  pkgs,
  user,
  ...
}: let
  cfg = config.modules.gh;
in {
  options.modules.gh.enable = lib.mkEnableOption "gh (GitHub CLI)";

  config = lib.mkIf cfg.enable {
    home-manager.users.${user}.programs.gh = {
      enable = true;

      extensions = with pkgs; [
        gh-dash
        gh-poi
        gh-notify
      ];

      settings = {
        git_protocol = "ssh";
        editor = "nvim";
        pager = "bat";
      };
    };
  };
}
