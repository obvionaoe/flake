{
  config,
  lib,
  pkgs,
  user,
  ...
}: let
  cfg = config.modules.containers;
in {
  # No `options` block here — modules/shared/containers already declares
  # modules.containers.enable; this module just reads it and adds the
  # Darwin-only daemon half. See modules/CLAUDE.md's coupled-module split.

  config = lib.mkIf cfg.enable {
    home-manager.users.${user} = {
      # Provides the actual docker daemon (via a Lima VM) that the `docker`
      # CLI installed in modules/shared/containers needs — nixpkgs has no
      # macOS-native docker daemon, and Docker Desktop isn't in nixpkgs at
      # all (proprietary, Homebrew-cask only). Colima is itself in nixpkgs
      # (tier 2), so it's preferred over reaching for a cask.
      home.packages = [pkgs.colima];

      # colima defaults its own state dir to ~/.colima, unless
      # $XDG_CONFIG_HOME is set — but only in the *absence* of a
      # pre-existing ~/.colima, which it otherwise falls back to for
      # backward compat while ignoring $XDG_CONFIG_HOME entirely (with a
      # warning). $XDG_CONFIG_HOME is also only ever exported into
      # interactive shells (via home-manager's session vars), never into
      # launchd's environment, so the launchd job below would silently
      # resolve to a different state dir than interactive `colima`
      # commands. Pin COLIMA_HOME explicitly everywhere instead — unlike
      # $XDG_CONFIG_HOME, it always takes precedence over the ~/.colima
      # fallback — so both contexts agree on the same instance.
      home.sessionVariables = {
        COLIMA_HOME = "${config.home-manager.users.${user}.xdg.configHome}/colima";
      };

      # `colima start` boots the VM and returns once it's up, so a plain
      # `KeepAlive = true` would spin it in a restart loop on every
      # successful exit. `SuccessfulExit = false` instead only re-runs it
      # after a failed start (e.g. a boot-time race). `colima start` is
      # idempotent — a no-op if the VM is already up — so StartInterval
      # lets launchd periodically re-invoke it to self-heal if the VM
      # itself later crashes, which the one-shot process exiting 0
      # wouldn't otherwise let launchd detect.
      launchd.agents.colima = {
        enable = true;
        config = {
          ProgramArguments = ["${pkgs.colima}/bin/colima" "start"];
          RunAtLoad = true;
          KeepAlive = {
            SuccessfulExit = false;
          };
          StartInterval = 300;
          EnvironmentVariables = {
            DOCKER_CONFIG = "${config.home-manager.users.${user}.xdg.configHome}/docker";
            COLIMA_HOME = "${config.home-manager.users.${user}.xdg.configHome}/colima";
            # launchd jobs get macOS's bare minimal PATH
            # (/usr/bin:/bin:/usr/sbin:/sbin), which doesn't include the
            # nix-installed `docker` CLI. `colima start` shells out to
            # look up `docker` as a dependency check on every *actual*
            # cold start (a fast path for an already-running VM skips
            # it) — without this, that check fails and the VM never
            # comes back up after a real crash.
            PATH = "${pkgs.docker}/bin:/usr/bin:/bin:/usr/sbin:/sbin";
          };
          StandardOutPath = "/Users/${user}/Library/Logs/colima.log";
          StandardErrorPath = "/Users/${user}/Library/Logs/colima.err.log";
        };
      };
    };
  };
}
