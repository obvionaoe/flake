{
  config,
  lib,
  user,
  ...
}: {
  # Half of modules/shared/cloud (which declares the enable option). Its
  # home.sessionVariables only reach shells, so GUI apps launched from the
  # Dock/Spotlight (DataGrip's AWS Toolkit) fall back to ~/.aws. Exporting the
  # same paths into launchd's user environment makes them see ~/.config/aws.
  config = lib.mkIf config.modules.cloud.enable {
    launchd.user.envVariables = let
      awsDir = "${config.home-manager.users.${user}.xdg.configHome}/aws";
    in {
      AWS_SHARED_CREDENTIALS_FILE = "${awsDir}/credentials";
      AWS_CONFIG_FILE = "${awsDir}/config";
    };
  };
}
