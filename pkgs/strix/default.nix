{
  lib,
  fetchurl,
  unstable,
}: let
  # version/url/hash live in source.json, not here — see ../CLAUDE.md.
  source = lib.importJSON ./source.json;

  # Built against nixpkgs-unstable's Python set: the pinned (stable) nixpkgs
  # is too far behind (openai-agents 0.6, openai < 2.45, no caido-sdk-client).
  python3Packages = unstable.python3Packages.overrideScope (final: prev: {
    # strix-agent pins openai-agents>=0.19,<0.20; nixpkgs-unstable is still on
    # 0.18. Drop this override once nixpkgs catches up.
    openai-agents = prev.openai-agents.overridePythonAttrs (old: rec {
      version = "0.19.4";
      src = final.fetchPypi {
        inherit version;
        pname = "openai_agents";
        hash = "sha256-/iF3juHoIWyc23dfqG0RsIvmjAGE4UAjmTCI0/gSwL4=";
      };
      # new runtime dependency in 0.19
      dependencies = old.dependencies ++ [final.websockets];
    });
  });
in
  # Installed from the PyPI platform wheel rather than built from the GitHub
  # source: the wheel ships the prebuilt Go TUI sidecar (strix/bin/strix-tui,
  # compiled by a hatch build hook) and the prebuilt Vite viewer bundle, so
  # this avoids a separate buildGoModule + vendorHash for the TUI. The Python
  # side, including every dependency, comes from nixpkgs. Only darwin-arm64 is
  # fetched since that's the only platform this flake currently builds for.
  # To bump: run `pkgs-update strix` — and re-check openai-agents above
  # against the new release's pins.
  python3Packages.buildPythonApplication {
    pname = "strix-agent";
    version = source.version;
    format = "wheel";

    # fetchurl keeps the wheel's filename, which the wheel installer needs
    # to read the platform tag from.
    src = fetchurl {
      url = source.url;
      hash = source.hash;
    };

    dependencies = with python3Packages;
      [
        caido-sdk-client
        cryptography
        cvss
        docker
        litellm
        markdown-it-py
        openai
        openai-agents
        pydantic
        pydantic-settings
        pypdf
        pyyaml
        reportlab
        requests
        rich
      ]
      # optional extras: `bedrock` (boto3) and `vertex` (google-auth). Strix
      # routes Vertex through litellm, which only needs google-auth —
      # google-cloud-aiplatform isn't required (and isn't in nixpkgs).
      ++ [
        boto3
        google-auth
      ];

    # Upper/lower bounds that nixpkgs-unstable's versions sit just outside of:
    # cryptography<49 (nixpkgs: 50.x), pydantic-settings>=2.13 (nixpkgs: 2.12).
    pythonRelaxDeps = [
      "cryptography"
      "pydantic-settings"
    ];

    # The bundled Go TUI is a prebuilt, ad-hoc-signed Mach-O; stripping it
    # invalidates that signature and macOS kills it on exec — same reasoning
    # as pkgs/decant and pkgs/soloterm.
    dontStrip = true;

    pythonImportsCheck = ["strix"];

    meta = {
      description = "Open-source AI pentesting agent that finds and validates app vulnerabilities";
      homepage = "https://github.com/usestrix/strix";
      license = lib.licenses.asl20;
      sourceProvenance = [
        lib.sourceTypes.fromSource
        lib.sourceTypes.binaryNativeCode # the bundled Go TUI
      ];
      platforms = ["aarch64-darwin"];
      mainProgram = "strix";
    };
  }
