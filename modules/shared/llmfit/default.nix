{
  config,
  lib,
  pkgs,
  user,
  ...
}: let
  cfg = config.modules.llmfit;
in {
  options.modules.llmfit.enable = lib.mkEnableOption "llmfit (TUI to find LLM models right sized for the system's RAM, CPU, and GPU)";

  config = lib.mkIf cfg.enable {
    home-manager.users.${user}.home.packages = [pkgs.unstable.llmfit];
  };
}
