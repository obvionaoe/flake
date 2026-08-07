{
  config,
  lib,
  pkgs,
  user,
  ...
}: let
  cfg = config.modules.trivy;
in {
  # Standalone on purpose — trivy's scope is broader than IaC (container
  # images, filesystem/secret scanning, Kubernetes manifests, SBOM), so it
  # doesn't belong bundled into any one concern-module. modules.terraform's
  # `.linting` tier default-enables this (see its `lib.mkDefault`, same
  # pattern as modules.claude-code -> modules.rtk) so today's IaC-scanning
  # use case still works out of the box, without requiring every future use
  # of trivy to drag in the whole terraform toolchain.
  options.modules.trivy.enable = lib.mkEnableOption "trivy (security/misconfiguration scanner)";

  config = lib.mkIf cfg.enable {
    home-manager.users.${user}.home.packages = [pkgs.trivy];
  };
}
