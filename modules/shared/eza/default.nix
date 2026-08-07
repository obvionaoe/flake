{
  config,
  lib,
  user,
  ...
}: let
  cfg = config.modules.eza;
in {
  options.modules.eza.enable = lib.mkEnableOption "eza (modern ls replacement)";

  config = lib.mkIf cfg.enable {
    home-manager.users.${user}.programs.eza = {
      enable = true;

      enableZshIntegration = config.modules.zsh.enable;

      extraOptions = [
        "--group-directories-first"
        "--header"
        "--long"
        "--all"
      ];

      git = true;
      icons = "always";
    };
  };
}
