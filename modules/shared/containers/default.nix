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
        home.packages = with pkgs; [docker crane skopeo kind];

        home.sessionVariables = {
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
