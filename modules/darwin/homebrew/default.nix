{
  config,
  user,
  nix-homebrew,
  homebrew-core,
  homebrew-cask,
  ...
}: {
  imports = [nix-homebrew.darwinModules.nix-homebrew];

  nix-homebrew = {
    inherit user;

    enable = true;
    enableRosetta = true;
    taps = {
      "homebrew/homebrew-core" = homebrew-core;
      "homebrew/homebrew-cask" = homebrew-cask;
    };
    mutableTaps = false;

    trust = {
      formulae = [];
      casks = [];
      commands = [];
      taps = [];
    };
    autoMigrate = true;
  };

  homebrew.enable = true;
  homebrew.enableZshIntegration = config.modules.zsh.enable;
  homebrew.taps = builtins.attrNames config.nix-homebrew.taps;

  # Any formula/cask/tap installed on the machine but not declared in some
  # module gets fully removed (app + support files + preferences) on the
  # next `darwin-rebuild switch`. Anything installed by hand for one-off
  # testing needs to be added to a module first, or it will be zapped.
  # Note: Mac App Store apps (homebrew.masApps) are exempt from this — see
  # nix-darwin's homebrew module docs, "unfortunately apps removed from
  # this option will not be uninstalled automatically... this is currently
  # a limitation of Homebrew Bundle."
  homebrew.onActivation.cleanup = "zap";
}
