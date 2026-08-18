{
  config,
  lib,
  pkgs,
  user,
  aps,
  ...
}: let
  cfg = config.modules.aps;
  apsPkg = aps.packages.${pkgs.stdenv.hostPlatform.system}.default;
in {
  options.modules.aps.enable = lib.mkEnableOption "aps (AWS profile switcher)";

  config = lib.mkIf cfg.enable {
    home-manager.users.${user} = {
      home.packages = [apsPkg];

      # Zsh integration deferred via zsh-defer (sourced by modules/shared/zsh)
      # instead of an eager `eval "$(aps init zsh)"` — that eval is a real
      # subprocess spawn that otherwise blocks every shell's first prompt on
      # it. Mirrors modules/shared/{zoxide,direnv}.
      programs.zsh.initContent = lib.mkIf config.modules.zsh.enable (
        lib.mkOrder 600 ''zsh-defer -c 'eval "$(${lib.getExe apsPkg} init zsh)"' ''
      );
    };
  };
}
