{
  config,
  lib,
  pkgs,
  user,
  ...
}: let
  cfg = config.modules.python;
in {
  options.modules.python.enable = lib.mkEnableOption "python3 (with pip, python-nmap) + virtualenv";

  config = lib.mkIf cfg.enable {
    home-manager.users.${user}.home.packages = with pkgs; [
      (python3.withPackages (python-pkgs:
        with python-pkgs; [
          pip
          python-nmap
        ]))
      virtualenv
    ];
  };
}
