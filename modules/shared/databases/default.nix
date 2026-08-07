{
  config,
  lib,
  pkgs,
  user,
  ...
}: let
  cfg = config.modules.databases;
in {
  options.modules.databases.enable = lib.mkEnableOption "database client tools (postgresql)";

  config = lib.mkIf cfg.enable {
    # `postgresql` is the full package (server included) rather than a
    # client-only build — nixpkgs doesn't ship a separate client-only
    # derivation, and this matches what the old flake installed for `psql`.
    # MySQL client tooling was dropped: nixpkgs removed real MySQL entirely
    # (mysql80 EOL'd 2026-04-30) and only offers mariadb.client as a
    # wire-compatible substitute, which isn't actually MySQL.
    home-manager.users.${user}.home.packages = with pkgs; [postgresql];
  };
}
