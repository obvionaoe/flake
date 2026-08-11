{
  config,
  lib,
  ...
}: {
  # Proprietary Logitech app with a background helper daemon for device
  # config (button remaps, per-device scroll direction, etc.) — not
  # packaged in nixpkgs, needs the vendor installer/cask like spotify does.
  options.modules.logi-options-plus.enable = lib.mkEnableOption "Logi Options+";

  config = lib.mkIf config.modules.logi-options-plus.enable {
    homebrew.casks = ["logi-options+"];
  };
}
