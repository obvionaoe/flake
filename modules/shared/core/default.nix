{
  self,
  nixpkgs-unstable,
  ...
}: {
  nix.settings.experimental-features = ["nix-command" "flakes"];
  # Old-style `nix-*` commands (nix-env, nix-channel, etc.) default to
  # scattering state directly under $HOME (~/.nix-defexpr, ~/.nix-profile);
  # this makes them follow XDG like the new `nix` CLI already does. Doesn't
  # move any existing files itself — see root CLAUDE.md's system-state rule,
  # this only touches nix.conf via the Nix module system, not $HOME.
  nix.settings.use-xdg-base-directories = true;
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
