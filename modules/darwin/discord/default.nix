{
  config,
  lib,
  ...
}: {
  # Was pkgs.unstable.discord via home.packages. nixpkgs' darwin build
  # extracts Discord's vendor-signed .app from its distro tarball, then
  # recreates every symlink in the bundle by hand (fixDistroSymlinks, working
  # around some shipping with mode 000) — that recreation invalidates Apple's
  # resource seal before home-manager ever touches it (confirmed: even a bare
  # `cp -R` of the untouched nix store output already fails `codesign
  # --verify`), so macOS reports "Discord is damaged and can't be opened."
  # A Homebrew cask installs a real, untouched, correctly-signed copy in
  # /Applications instead. Same symptom as modules/darwin/spotify, though the
  # root cause there is the home-manager copy step, not the nixpkgs build.
  options.modules.discord.enable = lib.mkEnableOption "Discord";

  config = lib.mkIf config.modules.discord.enable {
    homebrew.casks = ["discord"];
  };
}
