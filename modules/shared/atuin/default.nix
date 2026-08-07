{
  config,
  lib,
  pkgs,
  user,
  ...
}: let
  cfg = config.modules.atuin;
in {
  options.modules.atuin.enable = lib.mkEnableOption "atuin (shell history search)";

  config = lib.mkIf cfg.enable {
    home-manager.users.${user}.programs.atuin = {
      enable = true;

      # Client-only build: drops the server feature (and its dependencies)
      # this config never runs.
      package = pkgs.atuin.overrideAttrs (_: {
        cargoBuildNoDefaultFeatures = true;
        cargoBuildFeatures = ["client"];
      });

      enableZshIntegration = config.modules.zsh.enable;

      settings = {
        dialect = "uk";
        auto_sync = false;
        update_check = false;
        filter_mode_shell_up_key_binding = "session";
        filter_mode = "host";
        inline_height = 10;
        enter_accept = true;
        show_help = false;
      };
    };
  };
}
