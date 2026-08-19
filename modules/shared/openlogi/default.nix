{
  config,
  lib,
  pkgs,
  user,
  ...
}: let
  cfg = config.modules.openlogi;
in {
  # Local-first, open-source alternative to Logitech Options+ — no account,
  # no telemetry. In nixpkgs-unstable only (not yet in this flake's pinned
  # nixpkgs), hence pkgs.unstable (see modules/shared/vscode for the same
  # pattern). Replaces modules/darwin/logi-options-plus (the Homebrew cask)
  # now that a real package exists — tier 2 beats tier 3, per
  # modules/CLAUDE.md's "Where should a package come from?".
  options.modules.openlogi.enable = lib.mkEnableOption "OpenLogi (Logi Options+ replacement)";

  config = lib.mkIf cfg.enable {
    home-manager.users.${user} = {
      # Installs the `openlogi` CLI plus, on Darwin, an OpenLogi.app bundle
      # under Applications (copied to ~/Applications/Home Manager Apps by
      # home-manager's targets.darwin.copyApps, on by default on this
      # flake's home-manager pin — see modules/CLAUDE.md). On Linux this
      # also installs openlogi-agent and a systemd user service, which
      # nixpkgs enables on its own; nothing extra needed there.
      home.packages = [pkgs.unstable.openlogi];

      # Button remaps only work while the agent is running, so start the
      # app at login rather than relying on someone remembering to launch
      # it — same login-item pattern as modules/shared/ghostty. There's no
      # separate openlogi-agent binary on Darwin (Linux-only in nixpkgs);
      # the .app itself owns the agent. launchd.agents is a Darwin-only
      # home-manager option, safe to guard with pkgs.stdenv.isDarwin inside
      # a shared module (modules/CLAUDE.md's coupled-module exception).
      launchd.agents.openlogi = lib.mkIf pkgs.stdenv.isDarwin {
        enable = true;
        config = {
          ProgramArguments = ["/usr/bin/open" "-a" "OpenLogi"];
          RunAtLoad = true;
        };
      };
    };
  };
}
