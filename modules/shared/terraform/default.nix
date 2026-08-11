{
  config,
  lib,
  pkgs,
  user,
  ...
}: let
  cfg = config.modules.terraform;
in {
  options.modules.terraform = {
    enable = lib.mkEnableOption "terraform/OpenTofu toolchain (tenv, tf aliases)";
    linting.enable = lib.mkEnableOption "terraform linting/docs/security scanning (tflint, terraform-docs, + modules.trivy)";
  };

  config = lib.mkMerge [
    (lib.mkIf cfg.enable {
      home-manager.users.${user} = {
        # tenv is a terraform/OpenTofu *version manager* (like tenv/asdf) —
        # it provides the `terraform`/`tofu` shims itself, so no separate
        # `pkgs.terraform`/`pkgs.opentofu` package is installed here.
        home.packages = [pkgs.tenv];

        home.shellAliases = {
          tf = "terraform";
          tfi = "tf init";
          tfp = "tf plan";
          tfip = "tfi && tfp";
          tfa = "tf apply";
          tfia = "tfi && tfa";
          tfd = "tf destroy";
          tfid = "tfi && tfd";
          tfv = "tf validate";
          tfiv = "tfi && tfv";
          tfver = "tf version";
          tfw = "tf workspace";
          tfst = "tf state";
          tfstls = "tfst list";
          tfstmv = "tfst mv";
          tfstrm = "tfst rm";
          tfsts = "tfst show";
          tfc = "tf console";
          tfctx = "tf context";
          tff = "tf fmt -recursive";
          tffu = "tf force-unlock";
          tfg = "tf get";
          tfgr = "tf graph";
          tfimp = "tf import";
          tfo = "tf output";
          tfprov = "tf providers";
          tfr = "tf refresh";
          tfs = "tf show";
          tft = "tf taint";
          tfunt = "tf untaint";

          tfchk = ''_tfchk(){terraform init && terraform fmt -recursive && terraform-docs --lockfile=false . && terraform validate && if [ "$1" = "p" ]; then terraform plan; fi && tflint --init && tflint --recursive && trivy config . && rm -rf .terraform && rm .terraform.lock.hcl}; _tfchk'';
        };

        home.sessionVariables = {
          TENV_GITHUB_TOKEN = "$(gh auth token)";
        };
      };
    })

    (lib.mkIf (cfg.enable && cfg.linting.enable) {
      home-manager.users.${user}.home.packages = with pkgs; [tflint terraform-docs];

      # trivy (via `trivy config .` in tfchk below) replaces tfsec — frozen
      # upstream, fully merged into Trivy, same check IDs unchanged. It's
      # its own module (modules/shared/trivy) since its scope is broader
      # than IaC; default-enabled here so this tier still works out of the
      # box, same pattern as modules.claude-code -> modules.rtk. Note for any
      # future inline suppressions in .tf source: use `#trivy:ignore:...` or
      # a `.trivyignore` file, not the old `#tfsec:ignore:...` syntax, which
      # isn't reliably honored across trivy versions.
      modules.trivy.enable = lib.mkDefault true;
    })
  ];
}
