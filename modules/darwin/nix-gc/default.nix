{
  config,
  lib,
  ...
}: let
  cfg = config.modules.nix-gc;
in {
  # Darwin-only: `launchd.daemons` (and `nix.gc.interval`'s launchd
  # calendar-interval submodule) have no NixOS equivalent — this can't be a
  # `modules/shared/` module (modules/CLAUDE.md, "Platform-only options stay
  # in platform-only directories").
  options.modules.nix-gc.enable = lib.mkEnableOption "automatic nix store garbage collection";

  config = lib.mkIf cfg.enable {
    # `nix.gc.automatic` (+ `options`) only runs a single bare
    # `nix-collect-garbage <options>` — its `--delete-older-than` prunes
    # generations by age alone, with no way to also cap the *count* kept.
    # Getting "older than 30d OR beyond the 3 most recent" needs
    # `nix-env --delete-generations`, which supports both `30d` (age) and
    # `+3` (count) forms but only one per invocation — so this defines its
    # own `nix-gc` launchd daemon (bypassing `nix.gc.automatic` entirely)
    # that runs both passes against the system profile before reclaiming
    # the now-unreachable store paths. Order doesn't matter: each pass only
    # ever deletes generations, so whichever runs first can't un-delete
    # what the other would have removed.
    launchd.daemons.nix-gc = {
      script = ''
        set -euo pipefail
        ${config.nix.package}/bin/nix-env --delete-generations 30d --profile /nix/var/nix/profiles/system
        ${config.nix.package}/bin/nix-env --delete-generations +3 --profile /nix/var/nix/profiles/system
        ${config.nix.package}/bin/nix-collect-garbage
      '';
      serviceConfig.RunAtLoad = false;
      # Same schedule as nix-darwin's own `nix.gc.interval` default.
      serviceConfig.StartCalendarInterval = [
        {
          Weekday = 7;
          Hour = 3;
          Minute = 15;
        }
      ];
    };
  };
}
