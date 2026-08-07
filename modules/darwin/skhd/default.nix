{
  config,
  lib,
  user,
  home-manager,
  jackielii-tap,
  ...
}: {
  options.modules.skhd.enable = lib.mkEnableOption "skhd hotkey daemon";

  config = lib.mkIf config.modules.skhd.enable {
    nix-homebrew.taps = {"jackielii/homebrew-tap" = jackielii-tap;};
    nix-homebrew.trust.taps = ["jackielii/tap"];

    homebrew.casks = [
      {
        name = "jackielii/tap/skhd-zig";
        trusted = true;
        postinstall = "\${HOMEBREW_PREFIX}/bin/skhd --install-service";
      }
    ];

    home-manager.users.${user} = {
      xdg.configFile."skhd/skhdrc".text = ''
        cmd + ctrl - t : open -a Ghostty
      '';
    };
  };
}
