{
  config,
  lib,
  pkgs,
  user,
  ...
}: let
  cfg = config.modules.zoxide;
in {
  options.modules.zoxide.enable = lib.mkEnableOption "zoxide";

  config = lib.mkIf cfg.enable {
    home-manager.users.${user} = {
      programs.zoxide = {
        enable = true;
        # Zsh integration is hand-rolled below, deferred via zsh-defer
        # (sourced by modules/shared/zsh) instead of home-manager's eager
        # `eval "$(zoxide init zsh)"` — that eval is a real subprocess spawn
        # that otherwise blocks every shell's first prompt on it.
        enableZshIntegration = false;
      };

      # Reproduces home-manager's own zoxide.nix `programs.zsh.initContent`
      # exactly (mkOrder 851, no extra `.options` set here so `cfgOptions` is
      # empty), just deferred. Integrate only with shells this repo actually
      # manages — mirror modules/darwin/homebrew's gating.
      programs.zsh.initContent = lib.mkIf config.modules.zsh.enable (
        lib.mkOrder 600 ''zsh-defer -c 'eval "$(${lib.getExe pkgs.zoxide} init zsh)"' ''
      );
    };
  };
}
