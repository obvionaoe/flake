{
  config,
  lib,
  pkgs,
  user,
  ...
}: let
  cfg = config.modules.forgit;
in {
  options.modules.forgit.enable = lib.mkEnableOption "forgit (interactive git via fzf)";

  # forgit is a zsh plugin, so it only makes sense with both git and zsh
  # (specifically antidote, since that's how this flake manages zsh plugins).
  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = config.modules.git.enable && config.modules.zsh.enable;
        message = "modules.forgit requires modules.git and modules.zsh to be enabled";
      }
    ];

    home-manager.users.${user} = {
      home.sessionVariables = {
        FORGIT_NO_ALIASES = "1";
      };

      home.shellAliases = {
        ga = "forgit::add";
      };

      programs.zsh.antidote.plugins = ["wfxr/forgit"];
    };
  };
}
