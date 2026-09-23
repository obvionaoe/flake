{
  config,
  lib,
  pkgs,
  user,
  ...
}: let
  cfg = config.modules.opencode;
in {
  options.modules.opencode.enable = lib.mkEnableOption "opencode";

  config = lib.mkIf cfg.enable {
    home-manager.users.${user} = {
      # Desktop app, also from unstable for the same release-cadence reason
      # as the CLI below.
      home.packages = [pkgs.unstable.opencode-desktop];

      # home-manager ships `programs.opencode` (tier 1 per modules/CLAUDE.md's
      # package-source ordering), so no self-rolled wrapping needed.
      programs.opencode = {
        enable = true;

        # home-manager's own default package tracks the stable `nixpkgs`
        # input, which lags noticeably behind opencode's fast release cadence
        # (1.15.10 on the pinned nixos-26.05-darwin vs 1.18.18 on
        # nixpkgs-unstable, checked 2026-08-28). `pkgs.unstable` (overlaid by
        # modules/shared/core) picks up the newer build without pulling in
        # all of unstable.
        package = pkgs.unstable.opencode;

        # opencode-claude-auth is a plugin, not a CLI: opencode only loads it
        # when it's listed in `plugin`. Pointing at the nix-built entrypoint
        # (instead of the npm name) keeps opencode from fetching it from npm
        # at startup. Its only `@opencode-ai/plugin` import is type-only, so
        # the built dist/ needs nothing else to resolve.
        settings.plugin = [
          "file://${pkgs.unstable.opencode-claude-auth}/lib/node_modules/opencode-claude-auth/dist/index.js"
        ];
      };
    };
  };
}
