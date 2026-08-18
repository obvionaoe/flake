{...}: {
  nixpkgs.hostPlatform = "aarch64-darwin";
  system.primaryUser = "user";

  modules = {
    zsh.enable = true;
    zoxide.enable = true;
    git = {
      enable = true;
      # This host's identity is a real name + employer address, which must never
      # be committed to this public repo — it lives in an untracked file that
      # scripts/bootstrap.sh prompts for and writes on first run.
      identityFile = "~/.config/git/identity";
    };
    # This host's ssh-agent holds a work key alongside the personal one used
    # to push to public repos like this flake — see modules/shared/ssh for why
    # that needs an explicit alias rather than plain git@github.com.
    ssh = {
      enable = true;
      githubPersonal.enable = true;
    };
    direnv.enable = true;
    ghostty.enable = true;
    tmux.enable = true;
    neovim.enable = true;
    touchIdSudo.enable = true;
    skhd.enable = true;
    claude-code.enable = true;
    decant.enable = true;
    vscode.enable = true;
    nodejs.enable = true;
    bitwarden.enable = true;
    gnupg.enable = true;
    spotify.enable = true;
    ungoogled-chromium.enable = true;
    logi-options-plus.enable = true;

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
    soloterm.enable = true;
    bb.enable = true;
  };

  system.stateVersion = 7;
}
