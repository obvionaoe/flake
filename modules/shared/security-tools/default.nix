{
  config,
  lib,
  pkgs,
  user,
  ...
}: let
  cfg = config.modules.security-tools;

  # Wraps the real `strix` so it can never try to update itself — the flake
  # owns the version (bump via `pkgs-update strix` + rebuild):
  #
  # - `--update` is refused. argparse accepts any unambiguous prefix, and
  #   `--update` is strix's only `--u*` option, so every prefix from `--u`
  #   up is caught too. Scanning stops at `--`, after which argparse treats
  #   everything as positional.
  # - STRIX_NO_UPDATE_CHECK disables the background PyPI check, the startup
  #   notice, and the interactive "Update strix?" prompt. strix detects this
  #   install as `pip`, so answering `y` there would run `pip install
  #   --upgrade strix-agent` outside of Nix.
  #
  # `lib.getExe` resolves to the real binary's store path, so the wrapper
  # doesn't recurse into itself despite sharing the name `strix`.
  strix = pkgs.writeShellScriptBin "strix" ''
    set -euo pipefail
    for arg in "$@"; do
      [[ "$arg" == "--" ]] && break
      if [[ "''${#arg}" -ge 3 && "--update" == "$arg"* ]]; then
        echo "strix: self-update is disabled — this install is managed by Nix." >&2
        echo "strix: bump it with \`pkgs-update strix\` in ~/.flake, then rebuild." >&2
        exit 1
      fi
    done
    export STRIX_NO_UPDATE_CHECK=1
    exec ${lib.getExe pkgs.local.strix} "$@"
  '';
in {
  options.modules.security-tools.enable = lib.mkEnableOption "security tools (secret scanning, etc.)";

  config = lib.mkIf cfg.enable {
    home-manager.users.${user}.home.packages = [
      # nixpkgs-unstable rather than the pinned nixpkgs so trufflehog's
      # detector rules stay current with newly added secret formats.
      pkgs.unstable.trufflehog
      strix
    ];
  };
}
