{
  config,
  lib,
  user,
  ...
}: let
  cfg = config.modules.git;

  # Whichever of the two identity mechanisms this host uses, merged into
  # `programs.git.settings` below. Both halves are optional so a host declaring
  # neither gets no `[user]` section and no include at all, rather than an empty
  # one.
  userSection =
    lib.optionalAttrs (cfg.userName != null) {name = cfg.userName;}
    // lib.optionalAttrs (cfg.userEmail != null) {email = cfg.userEmail;};

  identity =
    lib.optionalAttrs (userSection != {}) {user = userSection;}
    # An out-of-repo identity file, for hosts whose name/email can't live here.
    # git ignores it when the file doesn't exist.
    // lib.optionalAttrs (cfg.identityFile != null) {include.path = cfg.identityFile;};

  # Not per-host: commits to *this* repo are always authored by the public
  # identity, on every host. `work`'s default identity deliberately isn't in the
  # repo, but its commits here still have to be — so this overrides whatever the
  # host's default identity is, for repos under `~/.flake` only.
  #
  # home-manager renders `programs.git.includes` with `mkAfter`, i.e. after
  # everything in `settings`, and git config is last-wins — so this beats both
  # the inline `[user]` and `identityFile`. Using `contents` rather than `path`
  # means home-manager generates the included file itself, in the store.
  flakeIdentity = {
    condition = "gitdir:~/.flake/";
    contents.user = {
      name = "obvionaoe";
      email = "obvionaoe@protonmail.com";
    };
  };
in {
  options.modules.git = {
    enable = lib.mkEnableOption "git";

    # Identity is per-host: `air` can declare it inline (it's the intentional
    # public identity), `work` cannot — a real name/employer address must never
    # land in this repo, so that host points `identityFile` at an untracked
    # file outside the repo instead. See "Public repository" in the root
    # CLAUDE.md.
    userName = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      example = "obvionaoe";
      description = ''
        `user.name` for this host. Only for identities that are safe to commit
        to a public repo — otherwise leave null and use `identityFile`.
      '';
    };

    userEmail = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      example = "obvionaoe@protonmail.com";
      description = ''
        `user.email` for this host. Only for identities that are safe to commit
        to a public repo — otherwise leave null and use `identityFile`.
      '';
    };

    identityFile = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      example = "~/.config/git/identity";
      description = ''
        Path to a git config file, outside this repo and not managed by it,
        pulled in via `include.path` — for hosts whose identity can't be
        committed here. The file is written by `scripts/bootstrap.sh`, which
        prompts for name/email on first run; git silently ignores it if it's
        missing, so a host with no identity yet still evaluates and builds.
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = (cfg.userName != null && cfg.userEmail != null) || cfg.identityFile != null;
        message = ''
          modules.git: this host has no git identity. Set both
          modules.git.userName and modules.git.userEmail (public identities
          only), or modules.git.identityFile for an out-of-repo one.
        '';
      }
    ];

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
        settings =
          {
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
          }
          // identity;

        includes = [flakeIdentity];

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
