{
  config,
  lib,
  user,
  ...
}: let
  cfg = config.modules.ssh;
in {
  options.modules.ssh = {
    enable = lib.mkEnableOption "ssh client config";

    defaultIdentityFile = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      example = "~/.ssh/air";
      description = ''
        For a host with exactly one GitHub-relevant key: pins plain
        `git@github.com` to this identity file, with `IdentitiesOnly` so ssh
        never offers any other key present on disk. Set per-host, not here —
        every host's relevant key has a different path/name.
      '';
    };

    githubPersonal.enable = lib.mkEnableOption ''
      the `github-personal` ssh alias, for a host whose agent holds more than
      one GitHub-registered key (e.g. a work key alongside a personal one) —
      see the option's own settings block below for why
    '';
  };

  config = lib.mkMerge [
    (lib.mkIf cfg.enable {
      home-manager.users.${user}.programs.ssh = {
        enable = true;

        # `matchBlocks` is home-manager's deprecated pre-`settings` API;
        # blocks below are declared directly as ssh_config(5) directives
        # instead. `enableDefaultConfig` opts out of home-manager's own
        # baked-in defaults (ForwardAgent/ControlMaster/etc, itself slated
        # for removal) rather than freezing a copy of them here.
        enableDefaultConfig = false;

        # macOS's ssh-agent is launchd-managed and starts empty on every
        # login/reboot — nothing re-adds keys to it on its own.
        # AddKeysToAgent re-adds a key to the running agent the first time
        # it's used; UseKeychain retrieves its passphrase from the macOS
        # Keychain instead of prompting, provided the key was added to
        # Keychain at least once (`ssh-add --apple-use-keychain ~/.ssh/<key>`
        # — a one-time, per-key, interactive step only the person holding the
        # passphrase can do). Applies to every host with this module enabled.
        # UseKeychain is an Apple OpenSSH extension a non-Apple ssh client
        # would error on as an unrecognized keyword; IgnoreUnknown makes this
        # block harmless if this module is ever imported on a non-Darwin host.
        settings."*" = {
          IgnoreUnknown = "UseKeychain";
          AddKeysToAgent = "yes";
          UseKeychain = "yes";
        };
      };
    })

    (lib.mkIf (cfg.enable && cfg.defaultIdentityFile != null) {
      home-manager.users.${user}.programs.ssh.settings."github.com" = {
        IdentityFile = cfg.defaultIdentityFile;
        IdentitiesOnly = true;
      };
    })

    (lib.mkIf (cfg.enable && cfg.githubPersonal.enable) {
      # A host whose ssh-agent holds more than one GitHub-registered key
      # can't rely on plain `git@github.com`: the agent offers keys in its
      # own order, and GitHub authenticates as whichever one it accepts
      # first — not necessarily the identity the current repo needs. This
      # alias pins the key explicitly (`IdentitiesOnly` stops ssh from
      # offering any other agent key), so
      # `git@github-personal:<owner>/<repo>.git` always authenticates as the
      # personal account regardless of what else is loaded.
      home-manager.users.${user}.programs.ssh.settings."github-personal" = {
        HostName = "github.com";
        User = "git";
        IdentityFile = "~/.ssh/personal";
        IdentitiesOnly = true;
      };
    })
  ];
}
