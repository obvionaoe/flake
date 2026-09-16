{
  config,
  lib,
  pkgs,
  user,
  ...
}: let
  cfg = config.modules.security-tools;
in {
  options.modules.security-tools.enable = lib.mkEnableOption "security tools (secret scanning, etc.)";

  config = lib.mkIf cfg.enable {
    # nixpkgs-unstable rather than the pinned nixpkgs so trufflehog's
    # detector rules stay current with newly added secret formats.
    home-manager.users.${user}.home.packages = [pkgs.unstable.trufflehog];
  };
}
