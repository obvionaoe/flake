{
  config,
  lib,
  pkgs,
  user,
  ...
}: let
  cfg = config.modules.fzf;
in {
  options.modules.fzf.enable = lib.mkEnableOption "fzf (fuzzy finder)";

  config = lib.mkIf cfg.enable {
    home-manager.users.${user} = {
      programs.fzf = {
        enable = true;
        tmux.enableShellIntegration = config.modules.tmux.enable;
        # Zsh integration is hand-rolled below, deferred via zsh-defer
        # (sourced by modules/shared/zsh) instead of home-manager's eager
        # `source <(fzf --zsh)` — that spawns a subprocess that otherwise
        # blocks every shell's first prompt on it.
        enableZshIntegration = false;
      };

      # Reproduces home-manager's own fzf.nix `programs.zsh.initContent`
      # exactly (the modern, embedded `--zsh` path — confirmed live via `nix
      # eval` that this pinned fzf version takes it), just deferred. The
      # `$options[zle] = on` guard home-manager wraps this in becomes
      # redundant under zsh-defer: it only ever runs a command when zle is
      # idle, which by definition means zle is on.
      programs.zsh.initContent = lib.mkIf config.modules.zsh.enable (
        lib.mkOrder 600 ''zsh-defer -c 'source <(${lib.getExe pkgs.fzf} --zsh)' ''
      );
    };
  };
}
