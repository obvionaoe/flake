{
  lib,
  stdenvNoCC,
  fetchurl,
}: let
  # version/url/hash live in source.json, not here — see ../CLAUDE.md.
  source = lib.importJSON ./source.json;
in
  # Prebuilt, ad-hoc-signed standalone (PyInstaller onefile) binary — not in
  # nixpkgs, and building it from the strix-agent PyPI package isn't viable
  # today: it pins openai-agents>=0.19,<0.20 and litellm>=1.101.0, both ahead
  # of what nixpkgs-unstable currently packages. Only darwin-arm64 is fetched
  # since that's the only platform this flake currently builds for. To bump:
  # run `pkgs-update strix`.
  stdenvNoCC.mkDerivation {
    pname = "strix";
    version = source.version;

    src = fetchurl {
      url = source.url;
      hash = source.hash;
    };

    sourceRoot = ".";

    installPhase = ''
      runHook preInstall
      mkdir -p "$out/bin"
      install -m755 "strix-${source.version}-macos-arm64" "$out/bin/strix"
      runHook postInstall
    '';

    # Ad-hoc code-signed; `strip` (part of the default fixup phase) invalidates
    # that signature and macOS kills the process on exec — same reasoning as
    # pkgs/decant and pkgs/soloterm. Skip fixup entirely rather than just
    # dontStrip.
    dontFixup = true;

    meta = {
      description = "Open-source AI pentesting agent that finds and validates app vulnerabilities";
      homepage = "https://github.com/usestrix/strix";
      license = lib.licenses.asl20;
      sourceProvenance = [lib.sourceTypes.binaryNativeCode];
      platforms = ["aarch64-darwin"];
      mainProgram = "strix";
    };
  }
