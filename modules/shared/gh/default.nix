{
  config,
  lib,
  pkgs,
  user,
  home-manager,
  ...
}: let
  cfg = config.modules.gh;

  settings = {
    git_protocol = "ssh";
    editor = "nvim";
    pager = "bat";
  };

  ghConfigDir = "${config.home-manager.users.${user}.xdg.stateHome}/gh";
  ghConfigSeed = (pkgs.formats.yaml {}).generate "gh-config-seed.yml" ({version = "1";} // settings);

  # Absolute path (PATH may not have gh yet when .zshenv runs) and with the
  # token vars stripped: `gh auth token` returns GH_TOKEN/GITHUB_TOKEN
  # verbatim when set, which would make a refresh just re-read the stale value.
  ghAuthToken = "GH_CONFIG_DIR=${ghConfigDir} env -u GH_TOKEN -u GITHUB_TOKEN ${lib.getExe config.home-manager.users.${user}.programs.gh.package} auth token 2>/dev/null";
in {
  options.modules.gh.enable = lib.mkEnableOption "gh (GitHub CLI)";

  config = lib.mkIf cfg.enable {
    home-manager.users.${user} = {
      programs.gh = {
        enable = true;
        extensions = with pkgs; [
          gh-dash
          gh-poi
          gh-notify
        ];
        inherit settings;
      };

      # programs.gh symlinks config.yml into the read-only nix store, but
      # `gh auth login` (and `gh auth switch`) still try to write to it —
      # this is a known, long-standing, still-open upstream gh issue
      # (cli/cli#4955, cli/cli#8357, cli/cli#8496), not something specific
      # to this machine. Point gh at a mutable dir instead, seeded once
      # from `settings` above; after that gh owns the file and nix never
      # touches it again.
      #
      # Deliberately not using GH_TOKEN as a workaround for the read-only
      # config: fixing the config path is the right fix. This doesn't touch
      # how the actual OAuth token is stored (still hosts.yml / OS keychain,
      # entirely gh-owned) — it only relocates the directory gh reads/writes.
      home.sessionVariables.GH_CONFIG_DIR = ghConfigDir;

      # Export gh's current token as GH_TOKEN, GITHUB_TOKEN and GITHUB_MCP_PAT
      # for tools that read those instead of gh's own credential store.
      # Resolved when hm-session-vars.sh is
      # sourced (once per login session, inherited by child shells), so the
      # token never lands in the repo or /nix/store. Consequences:
      #  - absolute gh path + inline GH_CONFIG_DIR, because .zshenv can run
      #    before PATH has gh and before other exports are visible;
      #  - the vars are only exported when gh is authed (a non-empty token
      #    came back); otherwise they stay unset rather than empty.
      # Uses sessionVariablesExtra (not sessionVariables) because it needs a
      # conditional, and it's appended to the same once-per-session file.
      # Plain POSIX sh — hm-session-vars.sh is sourced by non-zsh shells too
      # and by GUI-launched processes, which the zsh hook below can't reach.
      home.sessionVariablesExtra = ''
        _gh_token="$(${ghAuthToken})"
        if [ -n "$_gh_token" ]; then
          export GH_TOKEN="$_gh_token" GITHUB_TOKEN="$_gh_token" GITHUB_MCP_PAT="$_gh_token"
        fi
        unset _gh_token
      '';

      # Keeps already-open zsh shells (and tmux panes) current: the once-per-
      # session value above goes stale after `gh auth login`/`switch`/`refresh`.
      # Every one of those ends in gh's config Write(), which rewrites
      # hosts.yml (verified in cli/cli: Login and SwitchUser both go through
      # activateUser, and its Set() marks the map modified unconditionally,
      # so the file is rewritten even when nothing in it changed — the token
      # itself lives in the keyring, so the mtime is the only signal).
      # A prompt compares hosts.yml's mtime (one stat, no fork) and only runs
      # gh when it moved. The mtime the token was resolved at is exported
      # alongside it, so child shells/new tmux panes inherit a matching pair
      # and don't re-run gh. Logging out unsets the vars.
      programs.zsh.initContent = ''
        autoload -Uz add-zsh-hook
        zmodload -F zsh/stat b:zstat
        _gh_token_refresh() {
          local m
          m=$(zstat +mtime -F %s.%N ${ghConfigDir}/hosts.yml 2>/dev/null) || m=
          [[ $m == "$_GH_HOSTS_MTIME" ]] && return
          export _GH_HOSTS_MTIME=$m
          local t
          t="$(${ghAuthToken})"
          if [[ -n $t ]]; then
            export GH_TOKEN=$t GITHUB_TOKEN=$t GITHUB_MCP_PAT=$t
          else
            unset GH_TOKEN GITHUB_TOKEN GITHUB_MCP_PAT
          fi
        }
        add-zsh-hook precmd _gh_token_refresh
      '';

      # Only seeds once — after the first activation, `gh` owns this file,
      # so a future change to `settings` above won't reach an
      # already-seeded machine on its own. Run `gh config set <key>
      # <value>` or delete `${ghConfigDir}/config.yml` before rebuilding to
      # pick up a settings change.
      home.activation.ghConfigSeed = home-manager.lib.hm.dag.entryAfter ["writeBoundary"] ''
        if [[ ! -e "${ghConfigDir}/config.yml" ]]; then
          $DRY_RUN_CMD mkdir -p "${ghConfigDir}"
          $DRY_RUN_CMD cp "${ghConfigSeed}" "${ghConfigDir}/config.yml"
          $DRY_RUN_CMD chmod u+w "${ghConfigDir}/config.yml"
        fi
      '';
    };
  };
}
