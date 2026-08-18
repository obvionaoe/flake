{
  config,
  lib,
  pkgs,
  user,
  ...
}: let
  cfg = config.modules.atuin;

  # Client-only build: drops the server feature (and its dependencies) this
  # config never runs. Reused below (both for the actual package and for the
  # deferred init command) so the two can't drift apart.
  atuinPackage = pkgs.atuin.overrideAttrs (_: {
    cargoBuildNoDefaultFeatures = true;
    cargoBuildFeatures = ["client"];
  });
in {
  options.modules.atuin.enable = lib.mkEnableOption "atuin (shell history search)";

  config = lib.mkIf cfg.enable {
    home-manager.users.${user} = {
      programs.atuin = {
        enable = true;
        package = atuinPackage;

        # Zsh integration is hand-rolled below, deferred via zsh-defer
        # (sourced by modules/shared/zsh) instead of home-manager's eager
        # `eval "$(atuin init zsh)"` — that eval is a real subprocess spawn
        # that otherwise blocks every shell's first prompt on it.
        enableZshIntegration = false;

        settings = {
          dialect = "uk";
          auto_sync = false;
          update_check = false;
          filter_mode_shell_up_key_binding = "session";
          filter_mode = "host";
          inline_height = 10;
          enter_accept = true;
          show_help = false;
        };
      };

      # Reproduces home-manager's own atuin.nix `programs.zsh.initContent`
      # exactly (no `.flags` set here, matches its default `[]`), just
      # deferred. The `$options[zle] = on` guard home-manager wraps this in
      # becomes redundant under zsh-defer: it only ever runs a command when
      # zle is idle, which by definition means zle is on.
      programs.zsh.initContent = lib.mkIf config.modules.zsh.enable (
        lib.mkOrder 600 ''zsh-defer -c 'eval "$(${lib.getExe atuinPackage} init zsh)"' ''
      );
    };
  };
}
