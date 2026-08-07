{
  config,
  lib,
  pkgs,
  user,
  ...
}: let
  cfg = config.modules.go;
in {
  options.modules.go.enable = lib.mkEnableOption "go toolchain (gopls, gotests, air, cobra-cli, wgo)";

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
        gopls
        gotests
        air
        cobra-cli
        wgo
      ];

      home.shellAliases = {
        gomktest = "gotests -all -w -parallel";
        gowtest = ''_gowtest(){file=$(ls ./$1* | grep -Ev "^*_test.go$"); test=$(ls ./$1* | grep -E "^*_test.go$"); wgo go test $file $test}; _gowtest'';
      };
    };
  };
}
