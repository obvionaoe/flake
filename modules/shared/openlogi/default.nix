{
  config,
  lib,
  pkgs,
  user,
  home-manager,
  ...
}: let
  cfg = config.modules.openlogi;

  # Common Name of the locally-generated, self-signed code-signing
  # certificate used to sign the stable-path copy of openlogi-agent (see the
  # home.activation step below) — arbitrary, just needs to stay constant so
  # the same identity gets reused across rebuilds instead of minting a new
  # one every time.
  openlogiCodesignCN = "openlogi-agent-local-codesign";
  openlogiCodesignIdentifier = "local.flake.openlogi-agent";
  # Not a secret — only wraps the PKCS12 file macOS's `security import` needs
  # a non-empty password to parse (confirmed empirically: an empty password
  # fails with "MAC verification failed during PKCS12 import"), and that file
  # is deleted immediately after import within the same activation run.
  openlogiCodesignP12Pass = "openlogi-local-codesign";

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

    # Two MX Master 4 gesture-reliability fixes for this exact pinned version
    # (0.6.25), both verified live on real hardware with locally instrumented
    # builds before landing:
    #
    # - Raw-XY jump discard: gesture button/panel raw-XY reports occasionally
    #   carry an absolute-position jump instead of a real delta (reproduced
    #   live: single samples up to five figures, versus a few hundred for an
    #   entire deliberate swipe), which the agent summed like real motion —
    #   the jump alone crossed the swipe-commit threshold, so a
    #   left/right/up/down swipe randomly fired the wrong direction or
    #   nothing. The first attempt (skip only the first sample after contact)
    #   still let later jumps through; the landed fix is a plain magnitude
    #   sanity check applied to every raw-XY sample of a hold. Reported
    #   upstream as AprilNEA/OpenLogi#719 (against current master's
    #   restructured capture code — 0.6.25 predates that split, so this is a
    #   from-scratch backport, not a cherry-pick).
    #
    # - Capture-channel liveness watchdog: 0.6.25's capture session has no way
    #   to notice a HID++ channel that goes silently dead without an explicit
    #   disconnect (observed after a Bluetooth-direct device's sleep/wake
    #   cycle — the OS reports the mouse present again before the old
    #   channel's report delivery has actually recovered), so gestures can
    #   stop being recognized until the agent is restarted. Backported from a
    #   later upstream release that added exactly this ping-based watchdog;
    #   not yet confirmed as the fix for the sleep/wake symptom (that needs a
    #   real sleep/wake cycle to reproduce, unlike the jump discard above),
    #   but it's a real, already-upstreamed hardening regardless.
    #
    # Drop each half once a fix lands upstream and this version bumps past
    # whichever release picks it up.
    patches = (old.patches or []) ++ [./mx-master-4-gesture-fixes.patch];
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
      # Copying the build to one fixed, non-store path (instead of execing
      # the /nix/store binary directly) was the first attempt at avoiding a
      # re-grant of Accessibility/Input Monitoring on every rebuild that
      # touches this package. That reasoning turned out to be off (see
      # below), but the copy itself stays necessary regardless, for an
      # unrelated, purely mechanical reason: signing a binary means writing
      # a signature into it, and /nix/store is read-only — confirmed
      # directly against a real store path, writing to it is refused
      # outright, and codesign fails outright trying to sign a file it can't
      # write to. So this could never move to "codesign the store output at
      # build time" either, on top of the sandboxed builder having no
      # access to the login keychain a real signing identity lives in. This
      # binary is ad-hoc
      # signed (nixpkgs doesn't sign Darwin binaries with a real identity),
      # and confirmed empirically on this exact stable path — macOS keys an
      # ad-hoc binary's TCC grant to its CDHash (a hash of its own content),
      # not its path, so a rebuild that changes the binary's bytes (a patch,
      # a version bump, an unrelated dependency bump) invalidates the grant
      # even though the path never moves, with no new row appearing in
      # System Settings to explain why — the existing row just silently
      # stops matching. The actual fix is giving the copy a real, stable
      # signing identity: a self-signed code-signing certificate, generated
      # once into the login keychain and used to sign every copy with the
      # same identifier. Verified empirically with a disposable throwaway
      # binary before landing this: signed a build with this scheme, granted
      # it Accessibility once, rebuilt it with different content (different
      # CDHash), re-signed with the same identity, and the grant survived
      # with zero new prompts — confirming TCC keys a signed binary's grant
      # to the signing identity, not its content hash, same as it would for
      # a Developer-ID-signed app. That test also showed the certificate
      # doesn't need `security add-trusted-cert` for this to work — just
      # having it in the keychain with a private key is enough for codesign
      # to use it and for TCC to recognize it — so this doesn't add a
      # trusted root to the system, only a private, self-signed identity
      # scoped to signing this one binary. Since this identity is new, the
      # first activation run after it lands needs two one-time interactive
      # steps, both confirmed by literally running this exact script (not
      # just an equivalent by hand) before landing it: (1) the very first
      # `codesign` using the freshly-imported private key pops a macOS
      # "keychain wants to use this key" dialog — `security import`'s
      # `-T /usr/bin/codesign` does not suppress this on its own — click
      # "Always Allow", not just "Allow", or every future rebuild's
      # activation will hang on this same dialog again instead of signing
      # silently; and (2) the usual manual grant at System Settings >
      # Privacy & Security > Accessibility (and Input Monitoring) for
      # $HOME/.local/state/openlogi/openlogi-agent, not the /nix/store path,
      # since it's a genuinely new signing identity as far as TCC is
      # concerned. Neither should be needed again after that, regardless of
      # how many times the underlying binary gets rebuilt. Same
      # activation-copy pattern as modules/shared/rtk's
      # `home.activation.rtkInit`.
      home.activation.openlogiAgentStableCopy = home-manager.lib.hm.dag.entryAfter ["writeBoundary"] ''
        mkdir -p "$HOME/.local/state/openlogi"
        $DRY_RUN_CMD cp -f "${openlogi}/bin/openlogi-agent" "$HOME/.local/state/openlogi/openlogi-agent"
        $DRY_RUN_CMD chmod +x "$HOME/.local/state/openlogi/openlogi-agent"

        if ! /usr/bin/security find-certificate -c "${openlogiCodesignCN}" "$HOME/Library/Keychains/login.keychain-db" >/dev/null 2>&1; then
          openlogiCodesignTmp="$(mktemp -d)"
          ${pkgs.openssl}/bin/openssl req -x509 -newkey rsa:2048 -nodes -days 36500 \
            -subj "/CN=${openlogiCodesignCN}" \
            -addext "keyUsage=critical,digitalSignature" \
            -addext "extendedKeyUsage=critical,codeSigning" \
            -keyout "$openlogiCodesignTmp/key.pem" -out "$openlogiCodesignTmp/cert.pem"
          ${pkgs.openssl}/bin/openssl pkcs12 -export -legacy -passout pass:${openlogiCodesignP12Pass} \
            -inkey "$openlogiCodesignTmp/key.pem" -in "$openlogiCodesignTmp/cert.pem" \
            -out "$openlogiCodesignTmp/identity.p12"
          $DRY_RUN_CMD /usr/bin/security import "$openlogiCodesignTmp/identity.p12" -P "${openlogiCodesignP12Pass}" \
            -k "$HOME/Library/Keychains/login.keychain-db" -T /usr/bin/codesign
          rm -rf "$openlogiCodesignTmp"
        fi

        $DRY_RUN_CMD /usr/bin/codesign --force --sign "${openlogiCodesignCN}" \
          --identifier "${openlogiCodesignIdentifier}" \
          "$HOME/.local/state/openlogi/openlogi-agent"
      '';

      # Without these, the agent's output goes nowhere — launchd's default is
      # to discard stdout/stderr, so diagnosing anything wrong with it means
      # killing the managed process and re-running it by hand with
      # OPENLOGI_LOG=debug just to see what it's doing. A standing log file
      # costs nothing and turns that into a `tail`.
      launchd.agents.openlogi-agent = lib.mkIf pkgs.stdenv.isDarwin {
        enable = true;
        config = {
          ProgramArguments = ["/bin/sh" "-c" ''exec "$HOME/.local/state/openlogi/openlogi-agent"''];
          RunAtLoad = true;
          KeepAlive = true;
          StandardOutPath = "/Users/${user}/Library/Logs/openlogi-agent.log";
          StandardErrorPath = "/Users/${user}/Library/Logs/openlogi-agent.err.log";
        };
      };
    };
  };
}
