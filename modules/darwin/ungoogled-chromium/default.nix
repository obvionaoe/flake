{
  config,
  lib,
  ...
}: {
  options.modules.ungoogled-chromium.enable = lib.mkEnableOption "ungoogled-chromium browser";

  config = lib.mkIf config.modules.ungoogled-chromium.enable {
    homebrew.casks = ["ungoogled-chromium"];
  };
}
