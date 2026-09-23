{
  config,
  lib,
  pkgs,
  user,
  ...
}: let
  cfg = config.modules.containers;
in {
  # Old flake also had `vagrant` alongside docker/crane/skopeo/kind — dropped
  # as unused (not part of the KEEP triage).
  options.modules.containers = {
    enable = lib.mkEnableOption "container tooling (docker CLI, crane, skopeo, kind)";
    # Not "linting": there's no Dockerfile linter here, just trivy scanning a
    # *built* image for vulnerabilities — a different operation from static
    # analysis of source, unlike modules.terraform/kubernetes's .linting
    # tiers, which are mostly real linters.
    scanning.enable = lib.mkEnableOption "container image scanning (modules.trivy)";
  };

  config = lib.mkMerge [
    (lib.mkIf cfg.enable {
      home-manager.users.${user} = {
        # On Darwin, Docker Desktop (modules/darwin/containers) supplies its
        # own `docker` CLI alongside the daemon it provides — installing
        # nixpkgs' `docker` too would put two copies of the same binary on
        # PATH, fighting over the same DOCKER_CONFIG below. A future NixOS
        # host has no Docker Desktop, so it still needs this one.
        home.packages = with pkgs; [crane skopeo kind] ++ lib.optional (!pkgs.stdenv.isDarwin) docker;

        home.sessionVariables =
          {
            DOCKER_CONFIG = "${config.home-manager.users.${user}.xdg.configHome}/docker";
          }
          // lib.optionalAttrs pkgs.stdenv.isDarwin {
            # Docker Desktop's own GUI/daemon-management layer ignores
            # DOCKER_CONFIG (confirmed upstream: docker/for-mac#2635,
            # docker/for-mac#6150) and always reads/writes its
            # `desktop-linux` context into the default ~/.docker/config.json
            # — the CLI above, pointed at the relocated DOCKER_CONFIG, would
            # never see that context and would fall back to a "default"
            # context with no socket behind it. Sidestep context resolution
            # entirely by pointing straight at Docker Desktop's own fixed
            # daemon socket instead — a real ~/.docker path Desktop manages
            # itself, unrelated to DOCKER_CONFIG (see modules/darwin/containers).
            DOCKER_HOST = "unix:///Users/${user}/.docker/run/docker.sock";
          };

        home.shellAliases = {
          d = "docker";
          kindcc = "kind create cluster";
          kinddc = "kind delete cluster";
        };
      };
    })

    (lib.mkIf (cfg.enable && cfg.scanning.enable) {
      # default-enabled here, same pattern as modules.terraform.linting and
      # modules.kubernetes.linting.
      modules.trivy.enable = lib.mkDefault true;

      home-manager.users.${user}.home.shellAliases = {
        trivyimg = "trivy image";
      };
    })
  ];
}
