{
  config,
  lib,
  user,
  ...
}: {
  options.modules.keeper.keepAlive = lib.mkEnableOption "relaunching Keeper whenever it quits";

  # Keeper is an MDM-provisioned Mac App Store app (see the homebrew.masApps
  # note in hosts/darwin/work), so this module only keeps it running — it
  # doesn't install it. Same polling approach as modules/darwin/twingate.
  config = lib.mkIf config.modules.keeper.keepAlive {
    home-manager.users.${user}.launchd.agents.keeper-keepalive = {
      enable = true;
      config = {
        ProgramArguments = [
          "/bin/sh"
          "-c"
          "/usr/bin/pgrep -x 'Keeper Password Manager' >/dev/null || /usr/bin/open -g -a 'Keeper Password Manager'"
        ];
        StartInterval = 15;
        RunAtLoad = true;
        LimitLoadToSessionType = "Aqua";
      };
    };
  };
}
