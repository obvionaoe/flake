{
  config,
  lib,
  user,
  ...
}: let
  cfg = config.modules.android-studio;
in {
  options.modules.android-studio.enable = lib.mkEnableOption "Android Studio";

  config = lib.mkIf cfg.enable {
    homebrew.casks = ["android-studio"];

    home-manager.users.${user} = {
      # Android tooling defaults to ~/.android and ~/.gradle; these are the
      # env vars its own docs point to for relocating them under XDG. `adb`
      # doesn't read ANDROID_USER_HOME itself, so it needs the HOME
      # override alias instead.
      home.sessionVariables = {
        ANDROID_USER_HOME = "${config.home-manager.users.${user}.xdg.dataHome}/android";
        ANDROID_AVD_HOME = "${config.home-manager.users.${user}.xdg.dataHome}/android/avd";
        GRADLE_USER_HOME = "${config.home-manager.users.${user}.xdg.dataHome}/gradle";
      };

      home.shellAliases.adb = ''HOME="$XDG_DATA_HOME"/android adb'';
    };
  };
}
