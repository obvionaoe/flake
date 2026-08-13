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

      # A host whose ssh-agent holds more than one GitHub-registered key (e.g.
      # a work key alongside this personal one) can't rely on plain
      # `git@github.com`: the agent offers keys in its own order, and GitHub
      # authenticates as whichever one it accepts first — not necessarily the
      # identity the current repo needs. This alias pins the key explicitly
      # (`identitiesOnly` stops ssh from offering any other agent key), so
      # `git@github-personal:<owner>/<repo>.git` always authenticates as the
      # personal account regardless of what else is loaded.
      matchBlocks."github-personal" = {
        hostname = "github.com";
        user = "git";
        identityFile = "~/.ssh/personal";
        identitiesOnly = true;
      };
    };
  };
}
