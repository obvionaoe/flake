{
  config,
  lib,
  pkgs,
  user,
  ...
}: let
  cfg = config.modules.jdk;
in {
  options.modules.jdk.enable = lib.mkEnableOption "JDK toolchain (mvn, gradle)";

  config = lib.mkIf cfg.enable {
    home-manager.users.${user} = {
      programs.java.enable = true;
      programs.gradle.enable = true;

      home.packages = [pkgs.maven];
    };
  };
}
