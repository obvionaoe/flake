{
  pkgs,
  user,
  ...
}: {
  nixpkgs.hostPlatform = "aarch64-darwin";
  system.primaryUser = "obvionaoe";

  modules = {
    android-studio.enable = true;
    zsh.enable = true;
    zoxide.enable = true;
    git = {
      enable = true;
      userName = "obvionaoe";
      userEmail = "obvionaoe@protonmail.com";
    };
    # Only one GitHub-relevant key on this host, so plain git@github.com can
    # be pinned directly — no need for the work host's github-personal alias.
    ssh = {
      enable = true;
      defaultIdentityFile = "~/.ssh/air";
    };
    direnv.enable = true;
    ghostty.enable = true;
    tmux.enable = true;
    neovim.enable = true;
    touchIdSudo.enable = true;
    skhd.enable = true;
    agents.enable = true;
    decant.enable = true;
    aps.enable = true;
    vscode.enable = true;
    nodejs.enable = true;
    bitwarden.enable = true;
    gnupg.enable = true;
    spotify.enable = true;
    openlogi.enable = true;
    whatsapp.enable = true;
    plex.enable = true;
    ungoogled-chromium.enable = true;
    mullvad-vpn.enable = true;
    steam.enable = true;
    parsec.enable = true;
    geforce-now.enable = true;

    fonts.enable = true;
    macos-defaults.enable = true;
    eza.enable = true;
    bat.enable = true;
    fzf.enable = true;
    btop.enable = true;
    fastfetch.enable = true;
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
    nixd.enable = true;
    data-processors.enable = true;
    formatters.enable = true;

    firefox.enable = true;
    discord.enable = true;
    element.enable = true;
    obsidian.enable = true;
    microsoft-teams.enable = true;
    soloterm.enable = true;
    bb.enable = true;
  };

  # Air-only: don't mention Claude in commits (no "Co-Authored-By: Claude"
  # trailer or "Generated with Claude Code" line). Left at the module
  # default (on) on the work host.
  home-manager.users.${user}.programs.claude.settings.includeCoAuthoredBy = false;

  system.stateVersion = 7;
}
