{
  lib,
  stdenvNoCC,
  fetchurl,
}: let
  # version/url/hash live in source.json, not here — see ../CLAUDE.md.
  source = lib.importJSON ./source.json;
in
  # Prebuilt, ad-hoc-signed standalone binary (no nixpkgs package exists) —
  # only darwin-arm64 is fetched since that's the only platform this flake
  # currently builds for. To bump: run `pkgs-update decant`.
  stdenvNoCC.mkDerivation {
    pname = "decant";
    version = source.version;

    src = fetchurl {
      url = source.url;
      hash = source.hash;
    };

    sourceRoot = ".";

    installPhase = ''
      runHook preInstall
      mkdir -p "$out/bin"
      install -m755 decant "$out/bin/decant"
      runHook postInstall
    '';

    # The binary is ad-hoc code-signed; `strip` (part of the default fixup
    # phase) invalidates that signature and macOS kills the process on exec
    # (confirmed: a stripped copy gets SIGKILL'd rather than erroring) — verified
    # while packaging this, not a hypothetical. Skip fixup entirely rather than
    # just dontStrip, same reasoning as pkgs/soloterm.
    dontFixup = true;

    meta = {
      description = "Local-first analysis of Claude Code and Codex sessions: token spend, context windows, files touched, and cost";
      homepage = "https://github.com/dosu-ai/decant";
      license = lib.licenses.asl20;
      sourceProvenance = [lib.sourceTypes.binaryNativeCode];
      platforms = ["aarch64-darwin"];
      mainProgram = "decant";
    };
  }
