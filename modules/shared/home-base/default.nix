{
  user,
  pkgs,
  ...
}: {
  home-manager = {
    useGlobalPkgs = true;
    useUserPackages = true;
    # If activation would clobber a file that already exists outside Nix's
    # control (not from a previous generation), move it aside with this
    # suffix instead of aborting activation.
    backupFileExtension = "bak";
    users.${user} = {
      home = {
        stateVersion = "26.05";
        username = user;
        homeDirectory =
          if pkgs.stdenv.isDarwin
          then "/Users/${user}"
          else "/home/${user}";
      };
      xdg = {
        enable = true;
        localBinInPath = true;
      };
      # Global opt-in: any home-manager module that supports it (npm,
      # atuin, lazygit, kubecolor, readline, dircolors, github-copilot-cli,
      # codex, gtk2 as of this home-manager pin) relocates its own
      # dotfiles under XDG paths instead of flat files in $HOME.
      home.preferXdgDirectories = true;
    };
  };
}
