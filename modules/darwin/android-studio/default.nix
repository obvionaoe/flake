{
  config,
  lib,
  ...
}: {
  options.modules.android-studio.enable = lib.mkEnableOption "Android Studio";

  config = lib.mkIf config.modules.android-studio.enable {
    homebrew.casks = ["android-studio"];
  };
}
