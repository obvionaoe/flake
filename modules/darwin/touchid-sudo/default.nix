{
  config,
  lib,
  ...
}: {
  options.modules.touchIdSudo.enable = lib.mkEnableOption "Touch ID for sudo";

  config = lib.mkIf config.modules.touchIdSudo.enable {
    security.pam.services.sudo_local.touchIdAuth = true;
  };
}
