{
  config,
  lib,
  pkgs,
  user,
  ...
}: {
  options.modules.scratchpad.enable = lib.mkEnableOption "Scratchpad (trial build)";

  config = lib.mkIf config.modules.scratchpad.enable {
    home-manager.users.${user}.home.packages = [pkgs.local.scratchpad];

    # Global hotkey that toggles the Scratchpad window: ⌘⌥⇧N. Stored by the
    # app's KeyboardShortcuts library as JSON in Carbon codes (modifiers
    # 2816 = cmd 256 + shift 512 + option 2048; key code 45 = N). It's a
    # string value, not a nested dict. CustomUserPreferences writes per key
    # (`defaults write`), so the app's other prefs (window frames, etc.) are
    # left alone.
    system.defaults.CustomUserPreferences."com.sindresorhus.Scratchpad".KeyboardShortcuts_toggleWindow = builtins.toJSON {
      carbonModifiers = 2816;
      carbonKeyCode = 45;
    };
  };
}
