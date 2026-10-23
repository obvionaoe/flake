{
  config,
  lib,
  pkgs,
  user,
  ...
}: let
  cfg = config.modules.go;
in {
  options.modules.go.enable = lib.mkEnableOption "go toolchain (gopls, gotests, cobra-cli)";

  config = lib.mkIf cfg.enable {
    home-manager.users.${user} = {
      programs.go = {
        enable = true;

        env = {
          GOBIN = "${config.home-manager.users.${user}.home.homeDirectory}/.local/share/go/bin";
          GOPATH = "${config.home-manager.users.${user}.home.homeDirectory}/.local/share/go";
        };
      };

      home.packages = with pkgs; [
        unstable.gopls
        gotests
        cobra-cli
      ];

      home.shellAliases = {
        gomktest = "gotests -all -w -parallel";
      };
    };
  };
}
