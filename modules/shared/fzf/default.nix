{
  config,
  lib,
  user,
  ...
}: let
  cfg = config.modules.fzf;
in {
  options.modules.fzf.enable = lib.mkEnableOption "fzf (fuzzy finder)";

  config = lib.mkIf cfg.enable {
    home-manager.users.${user}.programs.fzf = {
      enable = true;

      enableZshIntegration = config.modules.zsh.enable;
      tmux.enableShellIntegration = config.modules.tmux.enable;
    };
  };
}
