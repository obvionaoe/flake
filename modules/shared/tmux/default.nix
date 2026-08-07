{
  config,
  lib,
  pkgs,
  user,
  ...
}: let
  cfg = config.modules.tmux;
in {
  options.modules.tmux.enable = lib.mkEnableOption "tmux";

  config = lib.mkIf cfg.enable {
    home-manager.users.${user}.programs.tmux = {
      enable = true;

      # C-Space instead of the default C-b: easier one-handed reach, and
      # doesn't collide with readline's C-b (back-char).
      shortcut = "Space";

      mouse = true;
      keyMode = "vi";
      terminal = "tmux-256color";
      # Sets both `base-index` (windows) and `pane-base-index` (panes).
      baseIndex = 1;
      escapeTime = 0;
      focusEvents = true;
      historyLimit = 50000;

      # Seamless C-h/j/k/l movement between tmux panes *and* Neovim splits.
      # Home-manager sources each plugin's script directly (no TPM needed),
      # so this alone is enough to get the is-vim-running-aware bindings —
      # paired with the nvim half of the same plugin in modules/shared/neovim.
      plugins = [pkgs.tmuxPlugins.vim-tmux-navigator];

      # Everything below has no first-class home-manager option (verified
      # against the module source), so it stays as raw tmux.conf.
      extraConfig = ''
        set -g renumber-windows on

        # True color + Kitty extended-keys passthrough. Without this, Ghostty
        # -> tmux -> Claude Code loses keys like Shift+Enter.
        set -as terminal-overrides ',*:RGB'
        set -g extended-keys always
        set -g extended-keys-format csi-u
        set -as terminal-features 'xterm*:extkeys'

        # --- Floating popups (Phase 1 placeholders) ---
        # Replaced with the custom Go binary's picker/cheatsheet subcommands
        # in Phase 2; kept here as working defaults in the meantime.
        bind-key s display-popup -E -w 80% -h 80% "tmux choose-tree -Zs"
        bind-key '?' display-popup -E -w 90% -h 80% "tmux list-keys | less"
      '';
    };
  };
}
