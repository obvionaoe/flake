{
  writeShellApplication,
  git,
  jq,
  nix,
  curl,
  gnused,
  gnugrep,
  coreutils,
}:
writeShellApplication {
  name = "pkgs-update";
  # runtimeInputs is on PATH for this script *and* every pkgs/<name>/update.sh
  # it shells out to, so individual update.sh scripts don't need to declare
  # their own dependencies.
  runtimeInputs = [git jq nix curl gnused gnugrep coreutils];
  text = builtins.readFile ../../scripts/pkgs-update.sh;
}
