{
  config,
  lib,
  user,
  ...
}: let
  cfg = config.modules.zoxide;
in {
  options.modules.zoxide.enable = lib.mkEnableOption "zoxide";

  config = lib.mkIf cfg.enable {
    home-manager.users.${user}.programs.zoxide = {
      enable = true;
      # Integrate only with shells this repo actually manages. zsh is the
      # only shell module today; mirror modules/darwin/homebrew's gating.
      enableZshIntegration = config.modules.zsh.enable;
    };
  };
}
