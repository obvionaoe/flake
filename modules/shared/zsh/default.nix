{
  config,
  lib,
  pkgs,
  user,
  zsh-min-plus,
  zsh-f-sy-h,
  zsh-async,
  ...
}: let
  cfg = config.modules.zsh;

  # One generated file: builds fpath, runs compinit once (cached), then
  # sources every plugin by its resolved Nix store path. No plugin manager —
  # no runtime git cloning (antidote used to clone into
  # ~/Library/Caches/antidote, entirely outside Nix, requiring a manual
  # `antidote update` to pick up upstream changes), no per-plugin
  # loop/stat/source at every shell start (what home-manager's own
  # `programs.zsh.plugins` does, and the actual cause of "home-manager zsh is
  # slow" on NixOS). Every plugin here is either a nixpkgs package or a flake
  # input (`zsh-min-plus`, `zsh-f-sy-h` — not in nixpkgs, or not the fork in
  # use), so updates are ordinary `nix flake update <input>` / nixpkgs bumps,
  # not something a shell has to notice and re-clone on its own.
  zshPluginInit = pkgs.writeText "zsh-plugin-init.zsh" ''
    # Schedules a command to run once zle is idle (in practice, within
    # milliseconds of the first prompt) instead of blocking startup on it.
    # Used below by modules/shared/{atuin,direnv,zoxide,fzf} to keep their
    # `eval "$(<tool> init zsh)"` subprocess spawns off the startup path —
    # those four `fork`+`exec`s are the actual dominant cost of shell
    # startup, not plugin loading.
    source ${pkgs.zsh-defer}/share/zsh-defer/zsh-defer.plugin.zsh

    fpath=(
      ${pkgs.zsh-completions}/share/zsh/site-functions
      $fpath
    )

    # Full compinit at most once a day (mtime check below); `-C` (skip the
    # security/staleness scan) the rest of the time, and the dump is
    # zcompiled for a faster parse. A completion added to fpath won't show up
    # until the cache expires — same tradeoff ez-compinit's own cache made.
    autoload -Uz compinit
    _zcompdump=${config.home-manager.users.${user}.xdg.cacheHome}/zsh/zcompdump
    if [[ -n $_zcompdump(#qN.mh+24) ]]; then
      compinit -d $_zcompdump
      zcompile -R -- $_zcompdump
    else
      compinit -C -d $_zcompdump
    fi
    unset _zcompdump

    # Order below is deliberate, per each plugin's own README: fzf-tab before
    # the highlighter/autosuggestions (it must be the last thing to bind
    # Tab), autopair before the highlighter (its own README asks for this),
    # highlighter before autosuggestions. compinit must run before fzf-tab,
    # since fzf-tab wraps the completion widget.
    source ${pkgs.zsh-fzf-tab}/share/fzf-tab/fzf-tab.plugin.zsh
    source ${pkgs.zsh-autopair}/share/zsh/zsh-autopair/autopair.zsh
    source ${zsh-f-sy-h}/F-Sy-H.plugin.zsh
    source ${pkgs.zsh-autosuggestions}/share/zsh/plugins/zsh-autosuggestions/zsh-autosuggestions.zsh
    source ${pkgs.zsh-you-should-use}/share/zsh/plugins/you-should-use/you-should-use.plugin.zsh

    # Prompt theme sourced directly (no promptinit/`prompt min_plus`) —
    # benchmarked ~7ms/shell faster, since promptinit scans $fpath for every
    # prompt_*_setup file (for `prompt -l`, unused here) and `prompt` has its
    # own dispatch cost on top. See obvionaoe/zsh-min-plus for the
    # promptinit-compatible entry point, kept there for other consumers.
    # zsh-async is sourced first — the theme's vcs_info runs on an async
    # worker rather than blocking every prompt on a synchronous git status.
    source ${zsh-async}/async.zsh
    source ${zsh-min-plus}/min-plus.zsh-theme
  '';
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

        # zshPluginInit above fully owns `compinit` now — home-manager's own
        # default (`autoload -U compinit && compinit`) would just
        # duplicate/race it.
        completionInit = "";

        initContent = lib.mkMerge [
          (lib.mkBefore (builtins.concatStringsSep "\n" [
            "setopt appendhistory beep promptsubst interactivecomments correct completealiases"
            "autoload -Uz colors && colors"
            "zstyle ':completion:*' menu select"
            "zstyle ':completion:*' rehash true"
            "zstyle ':completion:*' matcher-list '' 'm:{a-zA-Z}={A-Za-z}'"
          ]))
          (lib.mkOrder 550 "source ${zshPluginInit}")
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
