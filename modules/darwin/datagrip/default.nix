{
  config,
  lib,
  ...
}: {
  # nixpkgs' jetbrains.datagrip is Linux-only (no aarch64-darwin/x86_64-darwin
  # output) — the official Homebrew cask is the only viable install path here.
  options.modules.datagrip.enable = lib.mkEnableOption "DataGrip";

  config = lib.mkIf config.modules.datagrip.enable {
    homebrew.casks = ["datagrip"];
  };
}
