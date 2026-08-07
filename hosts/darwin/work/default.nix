{
  pkgs,
  user,
  ...
}: {
  nixpkgs.hostPlatform = "aarch64-darwin";
  system.primaryUser = "user";

  # Work identity override: repos under ~/work/ pick up name/email from
  # ~/.config/git/config-work instead of the public obvionaoe identity in
  # modules/shared/git. That file is created by hand on this machine and is
  # never managed by nix, so the actual work name/email never lands in this
  # public repo — see "Public repository" in the root CLAUDE.md.
  home-manager.users.${user}.programs.git.includes = [
    {
      condition = "gitdir:~/work/";
      path = "~/.config/git/config-work";
    }
  ];

  modules = {
    zsh.enable = true;
    zoxide.enable = true;
    git.enable = true;
    direnv.enable = true;
    ghostty.enable = true;
    tmux.enable = true;
    neovim.enable = true;
    touchIdSudo.enable = true;
    skhd.enable = true;
    claude-code.enable = true;
    vscode.enable = true;
    nodejs.enable = true;
    bitwarden.enable = true;
    spotify.enable = true;
    ungoogled-chromium.enable = true;

    fonts.enable = true;
    macos-defaults.enable = true;
    eza.enable = true;
    bat.enable = true;
    fzf.enable = true;
    btop.enable = true;
    atuin.enable = true;
    gh.enable = true;
    forgit.enable = true;
    cli-misc.enable = true;
    pkgs-update.enable = true;

    kubernetes = {
      enable = true;
      linting.enable = true;
      extras.enable = true;
    };
    terraform = {
      enable = true;
      linting.enable = true;
    };
    cloud.enable = true;
    containers = {
      enable = true;
      scanning.enable = true;
    };
    go.enable = true;
    python.enable = true;
    nixd.enable = true;
    data-processors.enable = true;
    formatters.enable = true;
    databases.enable = true;

    firefox.enable = true;
    obsidian.enable = true;
  };

  system.stateVersion = 7;
}
