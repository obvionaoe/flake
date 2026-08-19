{
  config,
  lib,
  pkgs,
  user,
  claude-code,
  nix-claude-code,
  ...
}: let
  cfg = config.modules.claude-code;
in {
  options.modules.claude-code.enable = lib.mkEnableOption "Claude Code";

  config = lib.mkIf cfg.enable {
    modules.rtk.enable = lib.mkDefault true;

    # claude-code-nix (the `claude-code` flake input) checks npm hourly
    # and bumps its package within ~30-60 minutes of a new release —
    # nixpkgs' own claude-code package can lag days to weeks behind
    # since it goes through normal PR review. This trades a small amount
    # of upstream-nixpkgs review/curation for staying current.
    #
    # Applying its overlay (rather than a plain home.packages entry) makes
    # pkgs.claude-code resolve to the fresh build everywhere it's referenced —
    # including nix-claude-code's `programs.claude.package` default below,
    # so declarative config and binary freshness compose for free.
    nixpkgs.overlays = [claude-code.overlays.default];

    nix.settings = {
      substituters = ["https://claude-code.cachix.org"];
      trusted-public-keys = ["claude-code.cachix.org-1:YeXf2aNu7UTX8Vwrze0za1WEDS+4DuI2kVeWEE4fsRk="];
    };

    home-manager.users.${user} = {
      # nix-claude-code (dryvist/nix-claude-code) gives ~/.claude a declarative
      # option surface — settings.json, permissions, MCP, hooks, plugins,
      # statusline. `homeModules.core` only wraps modules/core.nix (the binary
      # + enable flag) — the settings/permissions schema lives in
      # modules/default.nix, so `default` (aliased `claude`) is the only
      # export with that surface. Its sub-features (plugins, statusline,
      # hooks, mcp, latest, api-key-helper) each carry their own
      # `enable`/empty-by-default gate, so importing it doesn't turn
      # anything on beyond what's set below — consistent with this repo's
      # "importing a module costs nothing" rule (modules/CLAUDE.md).
      imports = [nix-claude-code.homeModules.default];

      # `claude-update`: bump only the Claude Code CLI input, then rebuild
      # this host. A real binary on PATH (not a shell alias) so it works in
      # any shell. `nix flake update` runs as the user (writes flake.lock);
      # only the switch needs root, so sudo is scoped to that half.
      home.packages = [
        (pkgs.writeShellScriptBin "claude-update" ''
          set -euo pipefail
          nix flake update claude-code --flake "$HOME/.flake"
          sudo darwin-rebuild switch --flake "$HOME/.flake"
        '')
      ];

      programs.claude = {
        enable = true;

        # Wraps the real `claude` binary in `direnv exec`, so any launcher
        # that execs `claude` directly instead of through an interactive
        # shell (soloterm does this) still gets direnv's env — including
        # `use nix`/`use flake` — applied first. `direnv exec DIR CMD` loads
        # DIR's .envrc (or is a harmless passthrough if there isn't one) and
        # then execs CMD with that env, so this is correct both inside and
        # outside a direnv-managed project, and adds nothing beyond one
        # extra fork+exec in an interactive shell that already ran direnv's
        # own zsh hook (modules/shared/direnv). `lib.getExe` resolves each
        # package's mainProgram to its store path, so the wrapper calls the
        # real binary directly — no PATH lookup, no recursion into itself
        # despite sharing the name `claude`. Only `home.packages` (via
        # nix-claude-code's `core.nix`) reads this option, so overriding it
        # doesn't disturb settings/hooks/statusline generation elsewhere.
        package = lib.mkIf config.modules.direnv.enable (
          pkgs.writeShellScriptBin "claude" ''
            set -euo pipefail
            exec ${lib.getExe pkgs.direnv} exec "$PWD" ${lib.getExe pkgs.claude-code} "$@"
          ''
        );

        # Note: `programs.claude.latest` (the official curl|bash installer,
        # which would shadow this Nix-managed binary on PATH) only exists
        # when nix-claude-code.homeModules.latest is imported — it isn't
        # here, so there's nothing to disable.

        # Nix-owned settings only. `permissions.allow`/`ask` are deliberately
        # left undeclared: nix-claude-code overwrites the *entire* array on
        # every rebuild, which would wipe out anything approved at runtime.
        # `deny` is a floor that should never silently change underneath you,
        # so it's safe (and worth) declaring here.
        settings = {
          env = {};
          permissions.deny = [];
        };

        # Connect every session to Remote Control (mobile/companion) at
        # startup by default, rather than needing `/remote-control` (or
        # equivalent) each session. Stored in ~/.claude.json, not
        # settings.json. https://code.claude.com/docs/en/remote-control
        remoteControlAtStartup = true;
      };
    };
  };
}
