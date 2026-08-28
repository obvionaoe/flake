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
    # home-manager ships `programs.opencode` (tier 1 per modules/CLAUDE.md's
    # package-source ordering), so no self-rolled wrapping needed.
    home-manager.users.${user}.programs.opencode = {
      enable = true;

      # home-manager's own default package tracks the stable `nixpkgs`
      # input, which lags noticeably behind opencode's fast release cadence
      # (1.15.10 on the pinned nixos-26.05-darwin vs 1.18.18 on
      # nixpkgs-unstable, checked 2026-08-28). `pkgs.unstable` (overlaid by
      # modules/shared/core) picks up the newer build without pulling in
      # all of unstable.
      package = pkgs.unstable.opencode;
    };
  };
}
