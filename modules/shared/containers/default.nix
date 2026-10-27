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
        # PATH. A future NixOS host has no Docker Desktop, so it still needs
        # this one.
        home.packages = with pkgs; [unstable.crane unstable.skopeo unstable.kind] ++ lib.optional (!pkgs.stdenv.isDarwin) docker;

        # Not on Darwin: Docker Desktop's own GUI/daemon-management layer
        # ignores DOCKER_CONFIG (docker/for-mac#2635, docker/for-mac#6150) and
        # always keeps its `desktop-linux` context, credential helper and
        # `cli-plugins` (compose, buildx) in the default ~/.docker. A CLI
        # pointed anywhere else sees none of that — `docker compose` and
        # `docker buildx` come back "unknown command" — so on macOS the CLI
        # stays on ~/.docker like Desktop does.
        home.sessionVariables = lib.optionalAttrs (!pkgs.stdenv.isDarwin) {
          DOCKER_CONFIG = "${config.home-manager.users.${user}.xdg.configHome}/docker";
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
