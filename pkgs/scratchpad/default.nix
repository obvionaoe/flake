{
  lib,
  stdenvNoCC,
  fetchurl,
  unzip,
}: let
  # version/url/hash live in source.json, not here — see ../CLAUDE.md.
  source = lib.importJSON ./source.json;
in
  # Sindre Sorhus's Scratchpad is a Mac App Store app; this is the vendor's
  # free trial build (a reminder to buy every 12 hours, no auto-update),
  # which is a direct zip download. Data/settings carry over if the App Store
  # version is bought later. To bump: run `pkgs-update scratchpad`.
  stdenvNoCC.mkDerivation {
    pname = "scratchpad";
    version = source.version;

    src = fetchurl {
      # The URL ends in a query string, so give the store path an explicit name.
      name = "Scratchpad-${source.version}-trial.zip";
      url = source.url;
      hash = source.hash;
    };

    nativeBuildInputs = [unzip];
    sourceRoot = ".";

    # The zip also carries a __MACOSX/ AppleDouble sidecar; extract only the app.
    unpackPhase = ''
      runHook preUnpack
      unzip -q "$src" 'Scratchpad.app/*'
      runHook postUnpack
    '';

    installPhase = ''
      runHook preInstall
      mkdir -p "$out/Applications"
      cp -r Scratchpad.app "$out/Applications/Scratchpad.app"
      runHook postInstall
    '';

    # Signed app — fixup (strip/patch) would break the code signature, same
    # reasoning as pkgs/soloterm.
    dontFixup = true;

    meta = {
      description = "Scratchpad — quick, always-available notes for macOS (trial build)";
      homepage = "https://sindresorhus.com/scratchpad";
      license = lib.licenses.unfree;
      sourceProvenance = [lib.sourceTypes.binaryNativeCode];
      platforms = lib.platforms.darwin;
    };
  }
