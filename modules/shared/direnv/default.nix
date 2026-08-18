{
  config,
  lib,
  pkgs,
  user,
  ...
}: let
  cfg = config.modules.direnv;
in {
  options.modules.direnv.enable = lib.mkEnableOption "direnv";

  config = lib.mkIf cfg.enable {
    home-manager.users.${user} = {
      programs.direnv = {
        enable = true;
        nix-direnv.enable = true;
        # Zsh integration is hand-rolled below, deferred via zsh-defer
        # (sourced by modules/shared/zsh) instead of home-manager's eager
        # `eval "$(direnv hook zsh)"` — that eval is a real subprocess spawn
        # that otherwise blocks every shell's first prompt on it.
        enableZshIntegration = false;
      };

      # Reproduces home-manager's own direnv.nix `programs.zsh.initContent`
      # exactly, just deferred. nix-direnv.enable doesn't change this command
      # — it only adds a separate direnvrc lib file direnv itself reads.
      programs.zsh.initContent = lib.mkIf config.modules.zsh.enable (
        lib.mkOrder 600 ''zsh-defer -c 'eval "$(${lib.getExe pkgs.direnv} hook zsh)"' ''
      );
    };
  };
}
