{
  config,
  lib,
  user,
  ...
}: let
  cfg = config.modules.git;
in {
  options.modules.git.enable = lib.mkEnableOption "git";

  # This module only ever sets the public obvionaoe/protonmail identity — see
  # "Public repository" in the root CLAUDE.md. A host that needs a different
  # identity (e.g. work) adds its own `programs.git.includes` conditional
  # include in that host's default.nix, pointing at a file outside this repo
  # that nix never manages, so no other name/email ever lands here. See
  # `hosts/darwin/work/default.nix` for the reference example.
  config = lib.mkIf cfg.enable {
    home-manager.users.${user} = {
      home.shellAliases = {
        g = "git";
        # Tag helpers: `gta <tag> [msg]` creates (from HEAD's message if no msg
        # given) and pushes a tag; `gtd <tag>` deletes it locally and remotely.
        gta = ''_gta(){if [ $# = 0 ]; then g tag; elif [ $# = 1 ]; then g tag -a "$1" -m "$(g log -1 --pretty=format:%B)" && g push --tags; elif [ $# = 2 ]; then g tag -a "$1" -m "$2" && g push --tags; else echo "error: wrong number of arguments"; fi}; _gta'';
        gtd = ''_gtd(){if [ $# = 1 ]; then g tag -d "$1" && g push origin :"$1"; else echo "error: wrong number of arguments"; fi}; _gtd'';
      };

      programs.git = {
        enable = true;

        # `settings` replaced both `extraConfig` and the plain `userName`/
        # `userEmail` options in recent home-manager — this is the full git
        # config attrset, not just identity.
        settings = {
          user.name = "obvionaoe";
          user.email = "obvionaoe@protonmail.com";

          alias = {
            b = "branch";
            bd = "branch -d";
            bD = "branch -D";
            c = "commit";
            cl = "clone";
            co = "checkout";
            d = "diff";
            i = "init";
            l = "log";
            p = "push";
            st = "status --short";
            u = "pull";

            sync = ''!git switch main && git pull --prune && git branch --format '%(refname:short) %(upstream:short)' | awk '$2 == "" { print $1 }' | xargs -r git branch -D'';
          };

          core = {
            autocrlf = "input";
            whitespace = "error";
          };
          http.sslVerify = "true";
          init.defaultBranch = "main";
          push.autoSetupRemote = "true";
          status = {
            showStash = true;
            showUntrackedFiles = "all";
          };
        };

        ignores = [
          "**.local.md"
          ".idea/"
          "*.iml"
          "cmake-build-*/"
          "*.iws"
          "out/"
          "*~"
          ".fuse_hidden*"
          ".directory"
          ".Trash-*"
          ".nfs*"
          "**/.terraform/*"
          "*.tfstate"
          "*.tfstate.*"
          "crash.log"
          "*.tfvars"
          "override.tf"
          "override.tf.json"
          "*_override.tf"
          "*_override.tf.json"
          ".terraformrc"
          "terraform.rc"
          ".vagrant/"
          "*.log"
          "*.box"
          ".vscode"
          "*.code-workspace"
          ".history/"
          ".history"
          ".ionide"
        ];
      };

      # `delta` moved out from under `programs.git.delta` into its own
      # top-level `programs.delta` module in recent home-manager.
      programs.delta = {
        enable = true;
        enableGitIntegration = true;

        options = {
          navigate = true;
          dark = true;
        };
      };
    };
  };
}
