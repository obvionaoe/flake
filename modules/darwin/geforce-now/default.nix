{
  config,
  lib,
  ...
}: {
  options.modules.geforce-now.enable = lib.mkEnableOption "NVIDIA GeForce NOW";

  config = lib.mkIf config.modules.geforce-now.enable {
    homebrew.casks = ["nvidia-geforce-now"];
  };
}
