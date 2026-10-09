{
  config,
  lib,
  artginzburg-tap,
  ...
}: {
  # Three-finger click/tap as a middle click. Closed source and not in
  # nixpkgs, so it comes from the author's own Homebrew tap. The free tier
  # covers the trackpad gestures; the app self-updates (Sparkle), which the
  # cask declares via `auto_updates`.
  options.modules.wheelclick.enable = lib.mkEnableOption "WheelClick (three-finger middle click)";

  config = lib.mkIf config.modules.wheelclick.enable {
    nix-homebrew.taps = {"artginzburg/homebrew-tap" = artginzburg-tap;};
    nix-homebrew.trust.taps = ["artginzburg/tap"];

    homebrew.casks = [
      {
        name = "artginzburg/tap/wheelclick";
        trusted = true;
      }
    ];
  };
}
