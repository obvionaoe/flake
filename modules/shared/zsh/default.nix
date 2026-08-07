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
    home-manager.users.${user} = {
      # Must be a top-level `home.sessionVariables` (sourced from .zshenv via
      # hm-session-vars.sh), not `programs.zsh.sessionVariables` (which only
      # lands in .zshrc) — Apple's Terminal.app session-restore hook runs
      # from /etc/zshrc, which is read *before* the user's .zshrc, so a
      # .zshrc-only var would be set too late to suppress it.
      home.sessionVariables.SHELL_SESSIONS_DISABLE = "1";

      programs.zsh = {
        enable = true;

        # Relative dotDir is deprecated by home-manager; use the absolute path.
        dotDir = "${config.home-manager.users.${user}.xdg.configHome}/zsh";

        # Plugin management is entirely via antidote — no
        # `programs.zsh.plugins`/`autosuggestion.enable`/
        # `syntaxHighlighting.enable`/`completionInit` (emptied out below),
        # any of which would either load a second, conflicting copy of
        # something already listed here, or fight with mattmc3/ez-compinit
        # over who owns `compinit`. Home-manager's antidote module resolves
        # this list to a single static, content-hashed bundle file at
        # *build* time (`antidote bundle` under the hood) instead of
        # `source`-ing each plugin's files individually at every shell
        # start.
        #
        # Order matches antidote's own official reference config
        # (github.com/getantidote/zdotdir): ez-compinit first so its
        # `compdef` shim is in place before anything else calls it — that
        # shim is what lets every other plugin here load in one flat list
        # regardless of order relative to `compinit` itself, since
        # ez-compinit queues `compdef` calls and only fires the real
        # `compinit` from a `precmd` hook (i.e. once the whole file,
        # including every fpath addition below, has already run — see
        # github.com/mattmc3/ez-compinit). Widget-wrapping plugins
        # (autopair, fzf-tab, the syntax highlighter, autosuggestions) are
        # still ordered deliberately at the tail, per their own READMEs:
        # fzf-tab before the highlighter/autosuggestions (it must be the
        # last thing to bind Tab), autopair before the highlighter (its own
        # README asks for this), highlighter before autosuggestions.
        antidote = {
          enable = true;
          useFriendlyNames = true;
          plugins = [
            "mattmc3/ez-compinit"
            "zsh-users/zsh-completions kind:fpath path:src"
            "Aloxaf/fzf-tab"
            # Custom prompt (old flake built this as a Nix package from the
            # same repo, `local.zsh.min-plus`; antidote can just clone it
            # directly as a plugin, so no separate package/overlay is
            # needed). kind:fpath only registers it for the
            # promptinit/`prompt` theme system (see `prompt min_plus` in
            # initContent below) — on its own it doesn't self-source, so
            # this alone doesn't activate it.
            "obvionaoe/zsh-min-plus kind:fpath"
            "hlissner/zsh-autopair"
            "z-shell/F-Sy-H"
            "zsh-users/zsh-autosuggestions"
            "MichaelAquilina/zsh-you-should-use"
          ];
        };

        autocd = true;

        sessionVariables = {
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

        # ez-compinit (first antidote plugin above) fully owns `compinit`
        # now — home-manager's own default
        # (`autoload -U compinit && compinit`) would just duplicate/race it.
        completionInit = "";

        initContent = lib.mkMerge [
          "autoload -Uz promptinit && promptinit && prompt min_plus"
          (lib.mkBefore (builtins.concatStringsSep "\n" [
            "setopt appendhistory beep promptsubst interactivecomments correct completealiases"
            "autoload -Uz colors && colors"
            # ez-compinit's own dump cache (skips compinit's slow -C
            # security/staleness check on repeat shells within 20h). Off by
            # default upstream because it can mask a completion you just
            # added to $fpath until the cache expires — worth remembering if
            # a new completion doesn't show up right after a rebuild.
            "zstyle ':plugin:ez-compinit' 'use-cache' 'yes'"
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
  };
}
