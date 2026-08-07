{
  config,
  lib,
  pkgs,
  user,
  ...
}: let
  cfg = config.modules.ghostty;
in {
  options.modules.ghostty.enable = lib.mkEnableOption "ghostty terminal";

  config = lib.mkIf cfg.enable {
    home-manager.users.${user} = {
      programs.ghostty = {
        enable = true;
        enableZshIntegration = true;

        # `ghostty` itself only builds from source on Linux (no Swift/Xcode
        # in the Nix sandbox). `ghostty-bin` repackages the official signed,
        # notarized macOS binary instead, so it works fine on Darwin too.
        package =
          if pkgs.stdenv.isDarwin
          then pkgs.ghostty-bin
          else pkgs.ghostty;

        settings = {
          font-size = 14;
          # Disables ligatures (contextual alternates) — old flake's pick,
          # carried forward since it was a deliberate readability choice.
          font-feature = "-calt";
          # `ghostty-bin` is a repackage of the official binary, not installed
          # via Sparkle's normal channel, so auto-update would just fail/nag.
          auto-update = "off";
          copy-on-select = false;
          mouse-hide-while-typing = true;
          scrollback-limit = 4294967295;
          # Native fullscreen requires window decorations to be present on
          # macOS, so this can't be `false` alongside `fullscreen = true`.
          window-decoration = true;
          fullscreen = true;
          # Left at the macOS default (false) so Ghostty stays resident after
          # the last window closes — otherwise the process exits and the
          # global quick-terminal keybind has nothing left to listen for it.
          quick-terminal-position = "top";
          quick-terminal-size = "50%,100%";
          # No window on launch, so the login-time launchd agent below starts
          # Ghostty silently in the background instead of throwing up a window.
          initial-window = false;
          keybind = [
            "global:super+escape=toggle_quick_terminal"
          ];
        };
      };

      # launchd.agents is a Darwin-only home-manager option, so it can't be
      # referenced unconditionally in a shared module (see modules/CLAUDE.md).
      # Starts Ghostty windowless at login so the quick terminal is available
      # immediately, without waiting for a first manual launch.
      launchd.agents.ghostty = lib.mkIf pkgs.stdenv.isDarwin {
        enable = true;
        config = {
          ProgramArguments = ["/usr/bin/open" "-a" "Ghostty"];
          RunAtLoad = true;
        };
      };
    };
  };
}
