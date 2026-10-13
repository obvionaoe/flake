{
  config,
  lib,
  user,
  ...
}: let
  cfg = config.modules.containers;
in {
  # modules/shared/containers declares modules.containers.enable; this module
  # reads it and adds the Darwin-only daemon half (see modules/CLAUDE.md's
  # coupled-module split), plus the Darwin-only keepAlive option below.
  options.modules.containers.keepAlive = lib.mkEnableOption "relaunching Docker Desktop whenever it quits";

  config = lib.mkIf cfg.enable {
    # Provides both the docker daemon (via Docker Desktop's own VM) and its
    # own `docker` CLI — nixpkgs has no macOS-native docker daemon, and
    # Docker Desktop isn't in nixpkgs at all (proprietary, Homebrew-cask
    # only). Docker Desktop's CLI is what modules/shared/containers'
    # `docker` shell alias resolves to on Darwin — that module skips
    # installing nixpkgs' `docker` there so there's only one `docker`
    # binary on PATH. The CLI's own config (credentials, plugins) still
    # gets XDG-relocated via DOCKER_CONFIG there, same as any other
    # platform — only Docker Desktop's *own* GUI/daemon state (the
    # `desktop-linux` context, its runtime socket) stays at the fixed
    # ~/.docker location it insists on regardless (upstream doesn't honor
    # DOCKER_CONFIG for that half: docker/for-mac#2635, #6150), which is
    # why modules/shared/containers also pins DOCKER_HOST straight at
    # Docker Desktop's fixed socket rather than relying on a context
    # lookup in the relocated config.
    homebrew.casks = ["docker-desktop"];

    home-manager.users.${user} = {
      # Docker Desktop's CLI symlinks default to ~/.docker/bin (its own
      # first-run setup, not something Homebrew/this flake controls) — it
      # normally self-adds that to PATH by editing the shell profile
      # directly, but home-manager's zsh module (modules/shared/zsh)
      # regenerates that profile from Nix on every activation and would
      # silently drop that edit again on the next switch. Declaring it here
      # instead makes it survive rebuilds. `/usr/local/bin` is also already
      # on macOS's default PATH regardless (via /etc/paths) and is where an
      # existing install may have put the symlinks instead, if "Install CLI
      # symlinks in /usr/local/bin" was ever enabled in Docker Desktop's
      # Advanced settings — either way `docker` still resolves.
      home.sessionPath = ["${config.home-manager.users.${user}.home.homeDirectory}/.docker/bin"];

      # Quitting Docker Desktop (or it crashing) takes the daemon down with it,
      # so relaunch it — same polling approach as modules/darwin/twingate.
      launchd.agents.docker-desktop-keepalive = lib.mkIf cfg.keepAlive {
        enable = true;
        config = {
          ProgramArguments = [
            "/bin/sh"
            "-c"
            "/usr/bin/pgrep -x 'Docker Desktop' >/dev/null || /usr/bin/open -g -a Docker"
          ];
          StartInterval = 15;
          RunAtLoad = true;
          LimitLoadToSessionType = "Aqua";
        };
      };
    };

    # Docker Desktop's own "Start Docker Desktop when you log in" preference
    # (on by default once it's been launched once) is what keeps the daemon
    # running across reboots — there's no nix-darwin equivalent to declare
    # that non-interactively, so this needs a one-time manual check in
    # Docker Desktop's Settings > General after the first `darwin-rebuild
    # switch` installs the cask. This replaces the colima launchd agent that
    # used to live here.
  };
}
