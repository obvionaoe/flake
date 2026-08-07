{
  config,
  lib,
  pkgs,
  user,
  ...
}: let
  cfg = config.modules.zsh;
in {
  options.modules.zsh.enable = lib.mkEnableOption "zsh";

  config = lib.mkIf cfg.enable {
    # system-level
    programs.zsh.enable = true;
    users.users.${user}.shell = pkgs.zsh;

    # home-manager-level
    home-manager.users.${user}.programs.zsh = {
      enable = true;

      # Relative dotDir is deprecated by home-manager; use the absolute path.
      dotDir = "${config.home-manager.users.${user}.xdg.configHome}/zsh";

      # Plugin management via antidote rather than home-manager's own
      # `plugins` list. Home-manager's antidote module resolves the plugin
      # list to a single static, content-hashed bundle file at *build* time
      # (`antidote bundle` under the hood) instead of `source`-ing each
      # plugin's files individually at every shell start — that per-plugin
      # sourcing/globbing is most of what made the old flake's plain
      # `programs.zsh.plugins` setup feel slow to start. `antidote load`
      # then just sources that one pre-resolved file.
      antidote = {
        enable = true;
        useFriendlyNames = true;
        plugins = [
          "hlissner/zsh-autopair"
          "zsh-users/zsh-completions"
          "zdharma-continuum/fast-syntax-highlighting"
          "zsh-users/zsh-autosuggestions"
          # Custom prompt (old flake built this as a Nix package from the
          # same repo, `local.zsh.min-plus`; antidote can just clone it
          # directly as a plugin, so no separate package/overlay is needed).
          "obvionaoe/zsh-min-plus"
        ];
      };

      autosuggestion.enable = true;
      syntaxHighlighting.enable = true;

      autocd = true;

      sessionVariables = {
        ZSH_CACHE_DIR = "${config.home-manager.users.${user}.xdg.cacheHome}/zsh";
        ZLE_RPROMPT_INDENT = "0";
      };

      shellAliases = {
        ll = "ls -la";
        gs = "git status";
        reload = "exec zsh";

        grep = "grep --color=auto";
        diff = "diff --color=auto";
        less = "less -R";
        cp = "cp -i";
        df = "df -h";
        tmpd = "cd $(mktemp -d)";
        b64d = ''_b64d(){echo "$1" | base64 -d}; _b64d'';
        b64e = ''_b64e(){echo -n "$1" | base64}; _b64e'';
        rebuild = "sudo darwin-rebuild switch --flake ~/.flake#${config.networking.hostName}";
      };

      history = {
        append = true;
        ignoreAllDups = true;
        ignoreDups = true;
        ignoreSpace = true;
        path = "${config.home-manager.users.${user}.xdg.dataHome}/zsh/zsh_history";
        size = 1000000000;
      };

      # Runs full `compinit` only if the completion dump is missing or more
      # than a day old, otherwise skips its (slow) security/staleness checks
      # via `-C`. Same idea as antidote's static bundling — pay the cost
      # once, not on every shell start.
      completionInit = ''
        autoload -Uz compinit
        _zcompdump_files=(''${ZDOTDIR:-$HOME}/.zcompdump(Nmh-24))
        if (( $#_zcompdump_files )); then
          compinit -C
        else
          compinit
        fi
        unset _zcompdump_files
        autoload -Uz +X bashcompinit && bashcompinit
      '';

      initContent = lib.mkMerge [
        (lib.mkBefore (builtins.concatStringsSep "\n" [
          "setopt appendhistory beep promptsubst interactivecomments correct completealiases"
          "autoload -Uz colors && colors"
          "zstyle ':completion:*' menu select"
          "zstyle ':completion:*' rehash true"
          "zstyle ':completion:*' matcher-list '' 'm:{a-zA-Z}={A-Za-z}'"
        ]))
        (lib.mkOrder 1000 (builtins.concatStringsSep "\n" [
          "bindkey '5~' kill-word"
          "bindkey '^H' backward-kill-word"
          "bindkey '^[[1;5C' forward-word"
          "bindkey '^[[1;5D' backward-word"
        ]))
      ];
    };
  };
}
