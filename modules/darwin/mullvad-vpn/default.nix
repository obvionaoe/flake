{
  config,
  lib,
  ...
}: {
  options.modules.mullvad-vpn.enable = lib.mkEnableOption "Mullvad VPN client";

  config = lib.mkIf config.modules.mullvad-vpn.enable {
    homebrew.casks = ["mullvad-vpn"];
  };
}
