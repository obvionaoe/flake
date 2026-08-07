{
  config,
  lib,
  pkgs,
  user,
  ...
}: let
  cfg = config.modules.formatters;
in {
  # tflint lives under modules.terraform.linting instead, to keep IaC linting
  # colocated with the rest of the terraform toolchain.
  options.modules.formatters.enable = lib.mkEnableOption "formatters/linters (alejandra, yamlfmt, yamllint)";

  config = lib.mkIf cfg.enable {
    home-manager.users.${user}.home.packages = with pkgs; [alejandra yamlfmt yamllint];
  };
}
