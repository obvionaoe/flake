{
  config,
  lib,
  user,
  ...
}: {
  options.modules.twingate.keepAlive = lib.mkEnableOption "relaunching Twingate whenever it quits";

  # Twingate itself is an MDM-provisioned Mac App Store app (see the
  # homebrew.masApps note in hosts/darwin/work), so this module only keeps it
  # running — it doesn't install it.
  config = lib.mkIf config.modules.twingate.keepAlive {
    home-manager.users.${user}.launchd.agents.twingate-keepalive = {
      enable = true;
      config = {
        # Poll rather than KeepAlive: `open -a` returns immediately, so launchd
        # would see the job "exit" and respin it in a loop, and running the
        # binary directly bypasses LaunchServices. `open -g` relaunches in the
        # background without stealing focus; `-a` is a no-op if it's running.
        ProgramArguments = [
          "/bin/sh"
          "-c"
          "/usr/bin/pgrep -x Twingate >/dev/null || /usr/bin/open -g -a Twingate"
        ];
        StartInterval = 15;
        RunAtLoad = true;
        LimitLoadToSessionType = "Aqua";
      };
    };
  };
}
