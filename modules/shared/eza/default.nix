{
  config,
  lib,
  pkgs,
  user,
  ...
}: let
  cfg = config.modules.eza;
in {
  options.modules.eza.enable = lib.mkEnableOption "eza (modern ls replacement)";

  config = lib.mkIf cfg.enable {
    home-manager.users.${user}.programs.eza = {
      enable = true;
      package = pkgs.unstable.eza;

      enableZshIntegration = config.modules.zsh.enable;

      extraOptions = [
        "--group-directories-first"
        "--header"
        "--long"
        "--all"
        # Hide macOS's .DS_Store and nothing else (exact-name glob, so
        # every other dotfile still shows under --all).
        "--ignore-glob=.DS_Store"
      ];

      git = true;
      icons = "always";
    };
  };
}
