{
  config,
  lib,
  user,
  ...
}: let
  cfg = config.modules.ssh;
in {
  options.modules.ssh.enable = lib.mkEnableOption "ssh client config";

  config = lib.mkIf cfg.enable {
    home-manager.users.${user}.programs.ssh = {
      enable = true;

      # `matchBlocks` is home-manager's deprecated pre-`settings` API; this
      # host's are declared directly as ssh_config(5) directives instead.
      # `enableDefaultConfig` opts out of home-manager's own baked-in
      # defaults (ForwardAgent/ControlMaster/etc, itself slated for removal)
      # rather than freezing a copy of them here — this module never needed
      # them, it only exists for the alias below.
      enableDefaultConfig = false;

      # A host whose ssh-agent holds more than one GitHub-registered key (e.g.
      # a work key alongside this personal one) can't rely on plain
      # `git@github.com`: the agent offers keys in its own order, and GitHub
      # authenticates as whichever one it accepts first — not necessarily the
      # identity the current repo needs. This alias pins the key explicitly
      # (`IdentitiesOnly` stops ssh from offering any other agent key), so
      # `git@github-personal:<owner>/<repo>.git` always authenticates as the
      # personal account regardless of what else is loaded.
      settings."github-personal" = {
        HostName = "github.com";
        User = "git";
        IdentityFile = "~/.ssh/personal";
        IdentitiesOnly = true;
      };
    };
  };
}
