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

      # `colima start` boots the VM in the background and returns, so this
      # only needs to run once at login — not KeepAlive, which would spin
      # it in a restart loop every time the command exits.
      launchd.agents.colima = {
        enable = true;
        config = {
          ProgramArguments = ["${pkgs.colima}/bin/colima" "start"];
          RunAtLoad = true;
          EnvironmentVariables = {
            DOCKER_CONFIG = "${config.home-manager.users.${user}.xdg.configHome}/docker";
          };
          StandardOutPath = "/Users/${user}/Library/Logs/colima.log";
          StandardErrorPath = "/Users/${user}/Library/Logs/colima.err.log";
        };
      };
    };
  };
}
