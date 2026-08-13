{
  lib,
  stdenvNoCC,
  fetchurl,
  undmg,
}: let
  # version/url/hash live in source.json, not here — see ../CLAUDE.md.
  source = lib.importJSON ./source.json;
in
  # Proprietary, signed+notarized arm64 .app distributed as a .dmg — not in
  # nixpkgs and no Homebrew cask exists, so we fetch + unpack the vendor dmg
  # directly, same shape as pkgs/soloterm. To bump: run `pkgs-update bb`.
  #
  # bb ships electron-updater (see its release's latest-mac.yml) and will
  # check for updates on launch. In-app self-update won't persist — the
  # store copy is read-only, and even the writable copy home-manager's
  # copyApps puts in ~/Applications gets re-copied from the pinned store
  # version on every darwin-rebuild switch — so any update it applies is
  # gone on the next rebuild. Updating means bumping source.json instead.
  stdenvNoCC.mkDerivation {
    pname = "bb";
    version = source.version;

    src = fetchurl {
      url = source.url;
      hash = source.hash;
    };

    nativeBuildInputs = [undmg];
    sourceRoot = ".";

    installPhase = ''
      runHook preInstall
      mkdir -p "$out/Applications"
      cp -r "bb.app" "$out/Applications/bb.app"
      runHook postInstall
    '';

    # Do NOT strip/patch — it's a signed, notarized app; fixup would break the
    # code signature and macOS would refuse to launch it (see pkgs/soloterm).
    dontFixup = true;

    meta = {
      description = "bb — agentic IDE that builds itself (getbb.app)";
      homepage = "https://getbb.app";
      # The get-bb/bb source is MIT; this derivation just fetches the vendor's
      # prebuilt signed binary rather than building from source (see above).
      license = lib.licenses.mit;
      sourceProvenance = [lib.sourceTypes.binaryNativeCode];
      platforms = ["aarch64-darwin"];
    };
  }
