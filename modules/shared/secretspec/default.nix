{
  config,
  lib,
  pkgs,
  user,
  ...
}: let
  cfg = config.modules.secretspec;
in {
  options.modules.secretspec.enable = lib.mkEnableOption "secretspec secrets manager";

  config = lib.mkIf cfg.enable {
    # The pinned nixpkgs (26.05-darwin) only carries secretspec 0.10.1;
    # nixpkgs-unstable has 0.19.0, so pull from pkgs.unstable — same pattern
    # as modules/shared/vscode's pkgs.unstable.vscode.
    home-manager.users.${user}.home.packages = [pkgs.unstable.secretspec];
  };
}
