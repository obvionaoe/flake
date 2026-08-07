{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.modules.fonts;
in {
  options.modules.fonts.enable = lib.mkEnableOption "fonts";

  config = lib.mkIf cfg.enable {
    # `fonts.packages` is a system-level option on both NixOS and nix-darwin
    # (nix-darwin symlinks into /Library/Fonts/Nix Fonts), so this is
    # genuinely cross-platform — not routed through home-manager.
    #
    # JetBrains Mono Nerd Font only. The old flake also carried Noto Sans/Serif
    # and Noto Color Emoji, but those were there to backfill what a bare NixOS
    # desktop lacks; macOS already ships system sans/serif fonts and Apple
    # Color Emoji, so pulling in Noto here would just be dead weight.
    fonts.packages = with pkgs; [
      nerd-fonts.jetbrains-mono
    ];
  };
}
