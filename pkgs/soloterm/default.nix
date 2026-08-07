{
  lib,
  stdenvNoCC,
  fetchurl,
  undmg,
}: let
  # version/url/hash live in source.json, not here — that's the only file
  # `pkgs-update`/`update.sh` ever writes to. See ./update.sh and
  # ../CLAUDE.md for the convention.
  source = lib.importJSON ./source.json;
in
  # Proprietary, signed+notarized universal .app distributed as a .dmg — not in
  # nixpkgs and no Homebrew cask exists, so we fetch + unpack the vendor dmg
  # directly. To bump: run `pkgs-update soloterm` (see ../pkgs-update).
  # In-app self-update won't persist (the store copy is read-only); updating
  # means bumping source.json.
  stdenvNoCC.mkDerivation {
    pname = "soloterm";
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
      cp -r "Solo.app" "$out/Applications/Solo.app"
      runHook postInstall
    '';

    # Do NOT strip/patch — it's a signed universal binary; fixup would break the
    # code signature and macOS would refuse to launch it.
    dontFixup = true;

    meta = {
      description = "Solo — native workspace for AI agents and dev processes (soloterm.com)";
      homepage = "https://soloterm.com";
      license = lib.licenses.unfree;
      sourceProvenance = [lib.sourceTypes.binaryNativeCode];
      platforms = lib.platforms.darwin;
    };
  }
