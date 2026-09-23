{
  config,
  lib,
  pkgs,
  user,
  ...
}: let
  cfg = config.modules.headroom-proxy;

  # Headroom has no native XDG support of its own (checked headroom/paths.py
  # in the wheel: it only understands $HEADROOM_CONFIG_DIR/
  # $HEADROOM_WORKSPACE_DIR, defaulting to a flat ~/.headroom) — but both
  # roots are independent overrides, so pointing them at real XDG locations
  # on the host is just a matter of setting those two env vars consistently
  # everywhere Headroom runs, container or native.
  xdg = config.home-manager.users.${user}.xdg;
  headroomConfigDir = "${xdg.configHome}/headroom";
  headroomStateDir = "${xdg.stateHome}/headroom";

  # Referenced both in the docker port mapping and in Claude Code's
  # ANTHROPIC_BASE_URL below — one binding so the two can't drift apart.
  proxyPort = 8787;
  proxyBaseUrl = "http://127.0.0.1:${toString proxyPort}";

  # On Darwin the `docker` CLI comes from the Docker Desktop cask
  # (modules/darwin/containers), not nixpkgs, and its actual location isn't
  # fixed: Docker Desktop's current default is `~/.docker/bin` (which it
  # normally self-adds to PATH, an edit home-manager's zsh module would wipe
  # out again on the next activation — modules/darwin/containers'
  # `home.sessionPath` is what actually keeps it on PATH here), but an
  # existing install may instead have it in `/usr/local/bin` from Docker
  # Desktop's own "Install CLI symlinks in /usr/local/bin" Advanced setting.
  # Rather than pinning to one (and getting it wrong again — this used to
  # assume nix-darwin's `config.homebrew.prefix`, which isn't even where
  # Docker Desktop puts its CLI), list every plausible location on PATH and
  # let plain `docker` resolve via lookup, the same as an interactive shell
  # would. Only used inside the launchd block below, which is itself already
  # guarded by `pkgs.stdenv.isDarwin`.
  dockerCliPaths = ["/Users/${user}/.docker/bin" "/usr/local/bin" "/opt/homebrew/bin"];
in {
  options.modules.headroom-proxy = {
    enable = lib.mkEnableOption "always-on Headroom proxy (Docker, localhost-only)";

    image = lib.mkOption {
      type = lib.types.str;
      default = "ghcr.io/headroomlabs-ai/headroom:0.37.0";
      description = ''
        Docker `image:tag` to run. Pinned rather than `:latest` — everything
        else in this flake is version/hash-pinned, and an unpinned tag would
        silently change what's running on the next restart/`docker pull`.
      '';
    };

    envFile = lib.mkOption {
      type = lib.types.str;
      default = "${headroomConfigDir}/env";
      description = ''
        Path to a `KEY=VALUE`-per-line file (docker `--env-file` format)
        holding provider credentials (`ANTHROPIC_API_KEY`, `OPENAI_API_KEY`,
        etc.) forwarded into the container. Never committed to this repo —
        create it by hand outside the flake, same as `modules/shared/git`'s
        `identityFile`. Only passed to `docker run` if it already exists, so
        the agent doesn't hard-fail before it's been created.
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    # docker CLI + daemon (Docker Desktop on Darwin) — see
    # modules/shared/containers and modules/darwin/containers.
    modules.containers.enable = lib.mkDefault true;
    # So there's something to point at the proxy below without a second,
    # separate opt-in — same cross-module-default pattern as
    # modules/shared/claude-code's own `modules.rtk.enable`.
    modules.claude-code.enable = lib.mkDefault true;

    home-manager.users.${user} = {
      # Routes Claude Code through the proxy, the same two settings.json
      # `env` keys `headroom wrap claude` would set (verified against
      # headroom/providers/claude/{install,runtime}.py in the wheel) — not
      # using `wrap` itself since it mutates ~/.claude/settings.json
      # imperatively, and nix-claude-code (modules/shared/claude-code)
      # already regenerates that file's `env`/permissions/plugins from Nix
      # on every activation, which would just fight `wrap` on the next
      # rebuild.
      #
      # ENABLE_TOOL_SEARCH: Claude Code stops deferring MCP/system tool
      # schemas — materializing every one into context — once
      # ANTHROPIC_BASE_URL is a non-default host (upstream GH #746);
      # this keeps deferral on.
      #
      # Known tradeoff, not fixable from here: Claude Code >=2.1.196
      # deterministically disables Remote Control (`/remote-control`,
      # which modules/shared/claude-code turns on via
      # `remoteControlAtStartup`) whenever ANTHROPIC_BASE_URL isn't
      # api.anthropic.com (upstream GH #1779) — this is a client-side
      # eligibility check headroom's own source says it cannot work around.
      programs.claude.settings.env = {
        ANTHROPIC_BASE_URL = proxyBaseUrl;
        ENABLE_TOOL_SEARCH = "true";
      };

      # launchd.agents is a Darwin-only home-manager option, safe to guard
      # with lib.mkIf pkgs.stdenv.isDarwin from a shared module —
      # modules/CLAUDE.md's coupled-module exception (see
      # modules/shared/openlogi for the same pattern).
      launchd.agents.headroom-proxy = lib.mkIf pkgs.stdenv.isDarwin {
        enable = true;
        config = {
          # A plist's ProgramArguments is a fixed list — building the
          # `--env-file` flag conditionally (only if envFile exists, so a
          # not-yet-created file doesn't hard-fail every launch) needs a
          # shell, not a bare argv.
          #
          # .claude mount matches upstream's own `proxy` service in
          # docker/docker-compose.native.yml (headroomlabs-ai/headroom),
          # minus its .codex/.gemini mounts (not used here) — that's other
          # tools' own config, out of scope for the XDG-ification above,
          # just along for cross-agent memory. headroom's own two roots are
          # remapped to
          # headroomConfigDir/headroomStateDir (see the `let` block) instead
          # of upstream's default nested-under-~/.headroom layout. Port is
          # bound to 127.0.0.1 only (upstream's compose file doesn't
          # restrict this), since the proxy forwards real provider API keys.
          ProgramArguments = [
            "/bin/sh"
            "-c"
            ''
              set -- --rm --name headroom-proxy -p 127.0.0.1:${toString proxyPort}:${toString proxyPort} \
                -e HOME=/tmp/headroom-home \
                -e HEADROOM_CONFIG_DIR=/headroom/config \
                -e HEADROOM_WORKSPACE_DIR=/headroom/state \
                -v ${headroomConfigDir}:/headroom/config \
                -v ${headroomStateDir}:/headroom/state \
                -v /Users/${user}/.claude:/tmp/headroom-home/.claude
              if [ -f "${cfg.envFile}" ]; then
                set -- "$@" --env-file "${cfg.envFile}"
              fi
              exec docker run "$@" ${cfg.image} headroom proxy --host 0.0.0.0 --port ${toString proxyPort}
            ''
          ];
          RunAtLoad = true;
          # `docker run` here is a foreground, blocking process (not `-d`),
          # so KeepAlive supervises the container's whole lifetime the same
          # way it would a plain binary — and doubles as a retry loop for
          # the startup race against Docker Desktop's own login-time launch
          # (see modules/darwin/containers): if the Docker daemon isn't up
          # yet, `docker run` just fails fast and gets relaunched.
          KeepAlive = true;
          EnvironmentVariables = {
            # Same XDG relocation + fixed-socket pairing as
            # modules/shared/containers: DOCKER_CONFIG moves the CLI's own
            # config XDG-ward, and DOCKER_HOST bypasses context resolution
            # (which would otherwise look for a `desktop-linux` context
            # Docker Desktop only ever writes into the default, unrelocated
            # ~/.docker/config.json — see modules/darwin/containers).
            DOCKER_CONFIG = "${config.home-manager.users.${user}.xdg.configHome}/docker";
            DOCKER_HOST = "unix:///Users/${user}/.docker/run/docker.sock";
            PATH = "${lib.concatStringsSep ":" dockerCliPaths}:/usr/bin:/bin:/usr/sbin:/sbin";
          };
          StandardOutPath = "/Users/${user}/Library/Logs/headroom-proxy.log";
          StandardErrorPath = "/Users/${user}/Library/Logs/headroom-proxy.err.log";
        };
      };
    };
  };
}
