{
  config,
  lib,
  pkgs,
  user,
  ...
}: let
  cfg = config.modules.openlogi;

  # Upstream nixpkgs never builds openlogi-agent on Darwin — cargoBuildFlags
  # only adds `--package=openlogi-agent` when stdenv.hostPlatform.isLinux,
  # even though the crate itself is cross-platform (its Cargo.toml pulls in
  # objc2/AppKit bindings for a macOS tray icon) and the same
  # Cargo.lock/vendor directory already covers its dependencies — this
  # looks like a plain packaging gap, not a real platform limitation.
  # Without the agent, the GUI starts but warns "agent not reachable and
  # its binary wasn't found next to the GUI" and nothing actually remaps
  # buttons. This override adds the extra --package flag and installs the
  # resulting binary next to `openlogi`, same as upstream's own Linux
  # installPhase branch — a minimal diff kept as an append rather than a
  # full installPhase rewrite, so it survives nixpkgs updates to the rest
  # of that phase.
  openlogi = pkgs.unstable.openlogi.overrideAttrs (old: {
    cargoBuildFlags =
      old.cargoBuildFlags
      ++ lib.optionals pkgs.stdenv.hostPlatform.isDarwin ["--package=openlogi-agent"];

    installPhase =
      old.installPhase
      + lib.optionalString pkgs.stdenv.hostPlatform.isDarwin ''
        install -Dm755 "$release_target/openlogi-agent" "$out/bin/openlogi-agent"
      '';
  });
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
      # flake's home-manager pin — see modules/CLAUDE.md) and the
      # openlogi-agent binary built by the override above. On Linux this
      # also installs openlogi-agent and a systemd user service, which
      # nixpkgs wires up on its own; nothing extra needed there.
      home.packages = [openlogi];

      # Button remaps only work while the agent is running, so start it at
      # login rather than relying on someone remembering to launch the app
      # — mirrors upstream's own Linux systemd user service
      # (openlogi-agent.service), just expressed as a launchd agent since
      # Darwin has no systemd. The GUI (OpenLogi.app) is only for
      # configuration and isn't autostarted; launch it manually when
      # needed, same as Options+'s menu bar app. launchd.agents is a
      # Darwin-only home-manager option, safe to guard with
      # pkgs.stdenv.isDarwin inside a shared module (modules/CLAUDE.md's
      # coupled-module exception).
      #
      # First run needs a one-time manual grant: System Settings > Privacy
      # & Security > Accessibility (and Input Monitoring) > add the agent
      # at its /nix/store path below, same as Options+ needed. The store
      # path is stable across unrelated rebuilds (Nix derivations are
      # content-addressed), so this grant shouldn't need repeating.
      launchd.agents.openlogi-agent = lib.mkIf pkgs.stdenv.isDarwin {
        enable = true;
        config = {
          ProgramArguments = ["${openlogi}/bin/openlogi-agent"];
          RunAtLoad = true;
          KeepAlive = true;
        };
      };
    };
  };
}
