{
  config,
  lib,
  pkgs,
  user,
  ...
}: let
  cfg = config.modules.search;
in {
  options.modules.search.enable = lib.mkEnableOption "ripgrep + fd (modern grep/find replacements)";

  config = lib.mkIf cfg.enable {
    # System-wide, not aliased over grep/find: ripgrep/fd have slightly
    # different flags than POSIX grep/find, so they're added as their own
    # `rg`/`fd` commands rather than shadowing the originals.
    home-manager.users.${user}.home.packages = with pkgs; [ripgrep fd];
  };
}
