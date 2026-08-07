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
  homebrew.onActivation.cleanup = "zap";
}
