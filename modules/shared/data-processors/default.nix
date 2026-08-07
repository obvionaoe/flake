{
  config,
  lib,
  pkgs,
  user,
  ...
}: let
  cfg = config.modules.data-processors;
in {
  # jq itself lives in modules.cli-misc already — this module is the rest of
  # the old flake's data-wrangling toolset: dasel (+ its many format-
  # conversion aliases), ijq, and prom2json.
  options.modules.data-processors.enable = lib.mkEnableOption "data processing tools (dasel, ijq, prom2json)";

  config = lib.mkIf cfg.enable {
    home-manager.users.${user} = {
      home.packages = with pkgs; [jq unstable.dasel ijq prom2json];

      home.shellAliases = {
        cq = "dasel -r csv";
        csv2json = "dasel -r csv -w json";
        csv2toml = "dasel -r csv -w toml";
        csv2yaml = "dasel -r csv -w yaml";
        csv2xml = "dasel -r csv -w xml";

        json2csv = "dasel -r json -w csv";
        json2toml = "dasel -r json -w toml";
        json2yaml = "dasel -r json -w yaml";
        json2xml = "dasel -r json -w xml";

        tq = "dasel -r toml";
        toml2csv = "dasel -r toml -w csv";
        toml2json = "dasel -r toml -w json";
        toml2yaml = "dasel -r toml -w yaml";
        toml2xml = "dasel -r toml -w xml";

        yq = "dasel -r yaml";
        yaml2csv = "dasel -r yaml -w csv";
        yaml2json = "dasel -r yaml -w json";
        yaml2toml = "dasel -r yaml -w toml";
        yaml2xml = "dasel -r yaml -w xml";

        xq = "dasel -r xml";
        xml2csv = "dasel -r xml -w csv";
        xml2json = "dasel -r xml -w json";
        xml2toml = "dasel -r xml -w toml";
        xml2yaml = "dasel -r xml -w yaml";
      };
    };
  };
}
