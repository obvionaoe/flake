{
  self,
  nixpkgs-unstable,
  ...
}: {
  nix.settings.experimental-features = ["nix-command" "flakes"];
  nixpkgs.config.allowUnfree = true;
  nixpkgs.overlays = [
    (final: prev: {
      unstable = import nixpkgs-unstable {
        system = prev.stdenv.hostPlatform.system;
        inherit (prev) config;
      };
    })
    # self-rolled derivations under pkgs/<name>/ — see pkgs/CLAUDE.md
    self.overlays.default
  ];
}
