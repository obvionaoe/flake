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
    home-manager.users.${user}.home.packages = [
      # nixpkgs-unstable rather than the pinned nixpkgs so trufflehog's
      # detector rules stay current with newly added secret formats.
      pkgs.unstable.trufflehog
      pkgs.local.strix
    ];
  };
}
