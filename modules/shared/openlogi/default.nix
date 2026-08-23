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

  # For generating config.toml declaratively (see cfg.settings/cfg.devices
  # below). Freeform, like programs.git.settings and modules/shared/gh's
  # ghConfigSeed, rather than hand-typing every OpenLogi key as a Nix option
  # — keeps this working across OpenLogi schema changes with no module edits.
  tomlFormat = pkgs.formats.toml {};

  # config.toml's device table is keyed
  # `<transport>:<vendorId>:<productId>:serial:<serial>` — the mouse's
  # hardware serial is baked into the key itself. ~/.flake is a public repo
  # (see root CLAUDE.md's "Public repository" section, which bans hardware
  # identifiers outright), so the serial can never be a Nix value. Verified
  # against the OpenLogi 0.6.25 source
  # (openlogi-agent-core/src/device_order.rs: DeviceStableId::physical_key())
  # that no serial-free key is possible — the agent looks devices up by exact
  # string, and a key without a real serial/unit id is never treated as a
  # physical device. So the seed file below is generated with a placeholder
  # in place of the serial, and home.activation.openlogiConfig (further down)
  # substitutes in the real one, resolved on this machine at activation time
  # via `openlogi list`.
  devicePlaceholder = name: "@OPENLOGI_SERIAL_${name}@";

  openlogiConfigContent = {
    schema_version = 3;
    app_settings = cfg.settings;
    devices =
      lib.mapAttrs' (name: dev:
        lib.nameValuePair "${dev.transport}:${dev.vendorId}:${dev.productId}:serial:${devicePlaceholder name}" dev.settings)
      cfg.devices;
    keyboard = {};
  };

  # Deliberately omits each device's `identity`/`model_info`/`capabilities`
  # sub-tables (display name, HID++ feature probe results, etc.) — those are
  # optional (config/device.rs: DeviceIdentity is `Option`, `#[serde(default)]`,
  # doc'd as "None for configs written before this field existed or by hand")
  # and are cache data OpenLogi repopulates itself once the device is online.
  # Nothing here needs to know or declare them.
  openlogiConfigSeed = tomlFormat.generate "openlogi-config-seed.toml" openlogiConfigContent;

  # One block per declared device: resolve its real serial on this machine
  # and queue a sed substitution for the placeholder above, or — if the
  # device can't be found at all, e.g. asleep/unpaired on a fresh machine —
  # flip allResolved off so home.activation.openlogiConfig leaves the
  # existing config.toml untouched rather than write one with a literal,
  # inert placeholder still in it.
  openlogiDeviceResolutionScript =
    lib.concatStrings (lib.mapAttrsToList (name: dev: ''
      vid="${dev.vendorId}"
      pid="${dev.productId}"
      # `openlogi list` has no --json output (checked: only -h/--help), so
      # this parses its human-readable block format, e.g.:
      #   MX Master 4 (—, vid=046d pid=b042)
      #     └─ slot 255 ● MX Master 4 (mouse, wpid=?, battery=25%...)
      #             model_ids=[...] ext=05 serial=2616ZAC170K8 unit_id=... transports=btle
      serial="$(${openlogi}/bin/openlogi list 2>/dev/null | /usr/bin/awk -v vid="$vid" -v pid="$pid" '
        /vid=/ { inBlock = ($0 ~ ("vid=" vid " pid=" pid)) }
        inBlock && match($0, /serial=[^ ]+/) { print substr($0, RSTART + 7, RLENGTH - 7); exit }
      ' | /usr/bin/tr '[:upper:]' '[:lower:]')"
      if ! [[ "$serial" =~ ^[a-z0-9]+$ ]]; then
        serial=""
      fi
      # Fall back to whatever serial is already on record for this exact
      # vendor/product, for a rebuild where the mouse happens to be
      # asleep/out of range — config.toml already uses the lowercased form.
      #
      # home-manager's activation PATH only has /bin, not /usr/bin (confirmed
      # empirically: awk/tr/grep/head/sed/mktemp/id all failed as bare names,
      # only /bin/{mkdir,cp,chmod,rm} resolved) — hence every /usr/bin/* tool
      # in this file is called by absolute path, same as the pre-existing
      # /usr/bin/security and /usr/bin/codesign calls above.
      if [ -z "$serial" ] && [ -f "$HOME/.config/openlogi/config.toml" ]; then
        serial="$(/usr/bin/grep -oE 'direct:${dev.vendorId}:${dev.productId}:serial:[a-z0-9]+' "$HOME/.config/openlogi/config.toml" | /usr/bin/head -1 | /usr/bin/sed -E 's/.*serial://')"
      fi
      if [ -z "$serial" ]; then
        echo "modules.openlogi: could not find a paired device for '${name}' (vid=${dev.vendorId} pid=${dev.productId}) — leaving ~/.config/openlogi/config.toml untouched this run" >&2
        allResolved=false
      else
        sedArgs+=(-e "s/${devicePlaceholder name}/$serial/g")
      fi
    '')
    cfg.devices);
in {
  # Local-first, open-source alternative to Logitech Options+ — no account,
  # no telemetry. In nixpkgs-unstable only (not yet in this flake's pinned
  # nixpkgs), hence pkgs.unstable (see modules/shared/vscode for the same
  # pattern). Replaces modules/darwin/logi-options-plus (the Homebrew cask)
  # now that a real package exists — tier 2 beats tier 3, per
  # modules/CLAUDE.md's "Where should a package come from?".
  options.modules.openlogi = {
    enable = lib.mkEnableOption "OpenLogi (Logi Options+ replacement)";

    # -> config.toml's [app_settings]. Defaults mirror this user's own
    # long-configured setup, so any host just needs `openlogi.enable = true;`
    # to get a fully preconfigured mouse — see home.activation.openlogiConfig
    # below for how this and `devices` actually reach config.toml.
    settings = lib.mkOption {
      type = tomlFormat.type;
      default = {
        launch_at_login = false;
        check_for_updates = false;
        auto_install_updates = false;
        update_prompt_seen = true;
        show_in_menu_bar = true;
        capture_mouse_events = true;
        auto_download_assets = true;
        asset_source = "automatic";
        thumbwheel_sensitivity = 14;
        appearance = "system";
      };
      description = ''
        OpenLogi's app-wide settings (config.toml's `[app_settings]`).
        Freeform — any key OpenLogi understands works, see
        `docs/CONFIGURATION.md` in its source (schema_version 3; the shipped
        copy of that doc is stale relative to v3's device-key scheme, but its
        `[app_settings]` keys are unaffected).
      '';
    };

    # -> config.toml's [devices."<transport>:<vendorId>:<productId>:serial:<serial>"],
    # minus the serial (see devicePlaceholder/openlogiDeviceResolutionScript
    # above for why). Attrset key here (e.g. "mx-master-4") is just a Nix-side
    # label, not persisted anywhere.
    devices = lib.mkOption {
      type = lib.types.attrsOf (lib.types.submodule {
        options = {
          transport = lib.mkOption {
            type = lib.types.str;
            default = "direct";
            description = "How this device is reached — \"direct\" for a Bluetooth/USB-direct HID++ connection (the only transport this module has been used with); OpenLogi also has receiver/raw/unknown key forms for other pairings.";
          };
          vendorId = lib.mkOption {
            type = lib.types.str;
            default = "046d";
            description = "USB vendor id, lowercase hex. 046d is Logitech.";
          };
          productId = lib.mkOption {
            type = lib.types.str;
            example = "b042";
            description = "USB product id, lowercase hex — identifies the device model, not the individual unit.";
          };
          settings = lib.mkOption {
            type = tomlFormat.type;
            default = {};
            description = ''
              Everything else in this device's config.toml entry — bindings,
              dpi, smartshift, invert_scroll, gesture_owner, etc. Freeform,
              same rationale as the top-level `settings` option above.
              Deliberately excludes `identity`/`model_info`/`capabilities`:
              those are optional, device-reported cache data that OpenLogi
              repopulates itself once the device is online.
            '';
          };
        };
      });
      default = {
        mx-master-4 = {
          productId = "b042";
          settings = {
            gesture_owner = "GestureButton";
            invert_scroll = true;
            dpi = 3200;
            dpi_presets = [3200];
            smartshift = {
              mode = "ratchet";
              auto_disengage = 40;
              tunable_torque = 75;
            };
            # gesture_owner above and each button name here are validated
            # leniently by OpenLogi (config/settings.rs:
            # deserialize_gesture_owner) — an unrecognized or miscased value
            # is silently treated as absent rather than rejected, so a typo
            # here fails quietly rather than at `nix flake check`.
            bindings = {
              MiddleClick = {
                Up = "MissionControl";
                Down = "ShowDesktop";
                Left = "PrevTab";
                Right = "NextTab";
                Click = "MiddleClick";
              };
              Back = {
                Up = "MissionControl";
                Down = "ShowDesktop";
                Left = "PrevTab";
                Right = "NextTab";
                Click = "MouseBack";
              };
              Forward = {
                Up = "MissionControl";
                Down = "ShowDesktop";
                Left = "PrevTab";
                Right = "NextTab";
                Click = "MouseForward";
              };
              GestureButton = {
                Up = "AppExpose";
                Down = "ShowDesktop";
                Left = "NextDesktop";
                Right = "PreviousDesktop";
                Click = "MissionControl";
              };
            };
          };
        };
      };
      description = ''
        Per-device config.toml entries, keyed by an arbitrary Nix-side label
        (not persisted). The serial that config.toml's real device key
        requires is never stored here or anywhere in this repo — it's
        resolved on each machine at activation time from `openlogi list`,
        by matching `vendorId`/`productId`. See
        home.activation.openlogiConfig.
      '';
    };
  };

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

      # Seeds ~/.config/openlogi/config.toml from cfg.settings/cfg.devices
      # above on *every* activation (not seed-once like modules/shared/gh's
      # ghConfigSeed/rtk's rtkInit) — the flake is meant to be the source of
      # truth here, so any tweak made through the OpenLogi GUI is reverted on
      # the next `darwin-rebuild switch`, in exchange for a new host coming
      # up with the mouse already configured the moment this module is
      # enabled.
      #
      # Must run after home-manager's own `setupLaunchAgents` step
      # (home-manager's modules/launchd/default.nix, darwin-only) has
      # (re)bootstrapped the agent, since the kickstart below needs the
      # launchd label to already exist. `setupLaunchAgents` isn't declared on
      # non-Darwin, so referencing it unconditionally from this shared module
      # would leave a dangling DAG dependency there — hence the
      # lib.optional guard, per modules/CLAUDE.md's shared-module rules.
      home.activation.openlogiConfig = home-manager.lib.hm.dag.entryAfter (["writeBoundary"] ++ lib.optional pkgs.stdenv.isDarwin "setupLaunchAgents") ''
        $DRY_RUN_CMD mkdir -p "$HOME/.config/openlogi"

        allResolved=true
        sedArgs=()

        ${openlogiDeviceResolutionScript}

        if [ "$allResolved" = true ]; then
          openlogiConfigTmp="$(/usr/bin/mktemp)"
          /usr/bin/sed "''${sedArgs[@]}" "${openlogiConfigSeed}" >"$openlogiConfigTmp"
          $DRY_RUN_CMD cp -f "$openlogiConfigTmp" "$HOME/.config/openlogi/config.toml"
          $DRY_RUN_CMD chmod 600 "$HOME/.config/openlogi/config.toml"
          rm -f "$openlogiConfigTmp"

          # OpenLogi has no file watcher and no CLI reload command (checked
          # its whole crates/ tree) — an externally written config.toml only
          # takes effect on agent restart. `-k` (kickstart, not just
          # start/stop) forces that even if the agent is already running.
          ${lib.optionalString pkgs.stdenv.isDarwin ''
            $DRY_RUN_CMD /bin/launchctl kickstart -k "gui/$(/usr/bin/id -u)/org.nix-community.home.openlogi-agent" || true
          ''}
        fi
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
