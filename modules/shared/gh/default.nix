{
  config,
  lib,
  pkgs,
  user,
  home-manager,
  ...
}: let
  cfg = config.modules.gh;

  settings = {
    git_protocol = "ssh";
    editor = "nvim";
    pager = "bat";
  };

  ghConfigDir = "${config.home-manager.users.${user}.xdg.stateHome}/gh";
  ghConfigSeed = (pkgs.formats.yaml {}).generate "gh-config-seed.yml" ({version = "1";} // settings);
in {
  options.modules.gh.enable = lib.mkEnableOption "gh (GitHub CLI)";

  config = lib.mkIf cfg.enable {
    home-manager.users.${user} = {
      programs.gh = {
        enable = true;
        extensions = with pkgs; [
          gh-dash
          gh-poi
          gh-notify
        ];
        inherit settings;
      };

      # programs.gh symlinks config.yml into the read-only nix store, but
      # `gh auth login` (and `gh auth switch`) still try to write to it —
      # this is a known, long-standing, still-open upstream gh issue
      # (cli/cli#4955, cli/cli#8357, cli/cli#8496), not something specific
      # to this machine. Point gh at a mutable dir instead, seeded once
      # from `settings` above; after that gh owns the file and nix never
      # touches it again. Same "declarative seed, then mutable" pattern as
      # modules/shared/rtk's `home.activation.rtkInit`.
      #
      # Deliberately not using GH_TOKEN as a workaround: a long-lived PAT
      # sitting in an env var/dotfile is a worse security posture than
      # fixing the config path. This doesn't touch how the actual OAuth
      # token is stored (still hosts.yml / OS keychain, entirely gh-owned)
      # — it only relocates the directory gh reads/writes.
      home.sessionVariables.GH_CONFIG_DIR = ghConfigDir;

      # Only seeds once — after the first activation, `gh` owns this file,
      # so a future change to `settings` above won't reach an
      # already-seeded machine on its own. Run `gh config set <key>
      # <value>` or delete `${ghConfigDir}/config.yml` before rebuilding to
      # pick up a settings change.
      home.activation.ghConfigSeed = home-manager.lib.hm.dag.entryAfter ["writeBoundary"] ''
        if [[ ! -e "${ghConfigDir}/config.yml" ]]; then
          $DRY_RUN_CMD mkdir -p "${ghConfigDir}"
          $DRY_RUN_CMD cp "${ghConfigSeed}" "${ghConfigDir}/config.yml"
          $DRY_RUN_CMD chmod u+w "${ghConfigDir}/config.yml"
        fi
      '';
    };
  };
}
