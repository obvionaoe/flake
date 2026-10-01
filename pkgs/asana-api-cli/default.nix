{
  lib,
  fetchurl,
  python3Packages,
}: let
  # version/url/hash live in source.json, not here — see ../CLAUDE.md.
  source = lib.importJSON ./source.json;
in
  # Installed from the pure-Python PyPI wheel; every dependency comes from the
  # pinned nixpkgs (python-asana there already satisfies the asana>=5.0.2,<6
  # pin). To bump: run `pkgs-update asana-api-cli` — and re-check that pin
  # against nixpkgs' python3Packages.asana.
  python3Packages.buildPythonApplication {
    pname = "asana-api-cli";
    version = source.version;
    format = "wheel";

    # fetchurl keeps the wheel's filename, which the wheel installer needs.
    src = fetchurl {
      url = source.url;
      hash = source.hash;
    };

    dependencies = with python3Packages; [
      asana
      click
      jq
      tabulate
    ];

    # Swap upstream's `asana-api` entry point for ./asana-api.py, which adds an
    # `auth login|status|token|logout` OAuth flow (upstream only takes a
    # bearer token) and otherwise hands off to upstream's CLI in-process.
    # wrapPythonPrograms runs after this, so the script still gets the nix
    # Python shebang and the dependency PYTHONPATH.
    postInstall = ''
      install -Dm755 ${./asana-api.py} $out/bin/asana-api
    '';

    pythonImportsCheck = ["asana_api_cli"];

    meta = {
      description = "Command-line wrapper around the official Asana Python SDK";
      homepage = "https://github.com/izumo-m/asana-api-cli";
      license = lib.licenses.mit;
      sourceProvenance = [lib.sourceTypes.fromSource];
      platforms = lib.platforms.all;
      mainProgram = "asana-api";
    };
  }
