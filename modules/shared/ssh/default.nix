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
      # ControlMaster/ControlPath/ControlPersist let the first SSH connection
      # to github.com stay open and get reused by every subsequent SSH-based
      # git operation (fetch/push/pull, hooks that shell out to git, etc.)
      # instead of paying a full handshake (~2-3s) each time. `home.file`
      # below creates the socket directory declaratively, since ControlPath
      # requires it to exist before the first connection.
      home-manager.users.${user} = {
        programs.ssh.settings."github.com" = {
          IdentityFile = cfg.defaultIdentityFile;
          IdentitiesOnly = true;
          ControlMaster = "auto";
          ControlPath = "~/.ssh/sockets/%r@%h-%p";
          ControlPersist = "10m";
        };

        home.file.".ssh/sockets/.keep".text = "";
      };
    })
  ];
}
