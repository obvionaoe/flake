{
  config,
  lib,
  ...
}: {
  # Was pkgs.spotify via home.packages. home-manager's copyApps mechanism
  # (default since home.stateVersion 25.11) copies .app bundles into
  # ~/Applications/Home Manager Apps instead of symlinking them specifically
  # to make Spotlight indexing work — but for Spotify specifically, the copy
  # corrupts its code signature (`codesign --verify` reports "code has no
  # resources but signature indicates they must be present"), and macOS
  # hides apps with invalid signatures from search/Launch Services. A
  # Homebrew cask installs a real, untouched, correctly-signed copy in
  # /Applications, sidestepping the copy step entirely.
  options.modules.spotify.enable = lib.mkEnableOption "Spotify";

  config = lib.mkIf config.modules.spotify.enable {
    homebrew.casks = ["spotify"];
  };
}
