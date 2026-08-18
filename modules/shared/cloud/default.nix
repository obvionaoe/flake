{
  config,
  lib,
  pkgs,
  user,
  ...
}: let
  cfg = config.modules.cloud;
in {
  # Only AWS and GCP — the old flake also had Azure and Contabo CLIs, dropped
  # as unused (not part of the KEEP triage).
  options.modules.cloud.enable = lib.mkEnableOption "cloud CLIs (awscli2, google-cloud-sdk)";

  config = lib.mkIf cfg.enable {
    home-manager.users.${user} = {
      home.packages = with pkgs; [
        awscli2
        (google-cloud-sdk.withExtraComponents (with google-cloud-sdk.components; [
          gke-gcloud-auth-plugin
        ]))
      ];

      home.sessionVariables = {
        AWS_SHARED_CREDENTIALS_FILE = "${config.home-manager.users.${user}.xdg.configHome}/aws/credentials";
        AWS_CONFIG_FILE = "${config.home-manager.users.${user}.xdg.configHome}/aws/config";
      };

      home.shellAliases = {
        gsp = ''_gsp(){ if [ -z "$1" ]; then gcloud config configurations activate default; else gcloud config configurations activate "$1"; fi } && _gsp'';
      };
    };
  };
}
