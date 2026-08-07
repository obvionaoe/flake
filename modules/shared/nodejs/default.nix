{
  config,
  lib,
  user,
  ...
}: let
  cfg = config.modules.nodejs;
in {
  options.modules.nodejs.enable = lib.mkEnableOption "Node.js";

  config = lib.mkIf cfg.enable {
    home-manager.users.${user} = {
      programs.npm.enable = true;

      # home.preferXdgDirectories (set globally in home-base) already moves
      # the npmrc file itself; these cover the rest npm's own docs call out
      # (cache/init-module/tmp) that home-manager's npm module doesn't
      # relocate on its own. Doesn't move the existing ~/.npm cache — that's
      # a manual one-time cleanup.
      home.sessionVariables = {
        NPM_CONFIG_INIT_MODULE = "${config.home-manager.users.${user}.xdg.configHome}/npm/config/npm-init.js";
        NPM_CONFIG_CACHE = "${config.home-manager.users.${user}.xdg.cacheHome}/npm";
        NPM_CONFIG_TMP = "${config.home-manager.users.${user}.xdg.stateHome}/npm/tmp";
      };
    };
  };
}
