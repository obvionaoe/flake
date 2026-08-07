{
  config,
  lib,
  ...
}: {
  # nixpkgs only has this as `teams-for-linux` (Linux-branded, not ideal for
  # macOS) — the official Homebrew cask is the sane choice here.
  options.modules.microsoft-teams.enable = lib.mkEnableOption "Microsoft Teams";

  config = lib.mkIf config.modules.microsoft-teams.enable {
    homebrew.casks = ["microsoft-teams"];
  };
}
