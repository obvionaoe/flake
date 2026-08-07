{
  config,
  lib,
  pkgs,
  user,
  ...
}: let
  cfg = config.modules.bitwarden;
in {
  options.modules.bitwarden.enable = lib.mkEnableOption "Bitwarden password manager";

  config = lib.mkIf cfg.enable {
    # nixpkgs' bitwarden-desktop on the pinned (26.05-darwin) nixpkgs still
    # bundles an EOL/insecure Electron and refuses to build; nixpkgs-unstable
    # fixed it as of 2026-08-03 (bitwarden-desktop 2026.7.0), so this pulls
    # from pkgs.unstable rather than plain pkgs — same pattern as
    # modules/shared/vscode's pkgs.unstable.vscode. Recheck the pinned
    # `nixpkgs` input periodically and drop `.unstable` once it catches up.
    home-manager.users.${user}.home.packages = [pkgs.unstable.bitwarden-desktop];
  };
}
