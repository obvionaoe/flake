{
  description = "obvionaoe's flake";

  inputs = {
    nixpkgs.url = "nixpkgs/nixpkgs-26.05-darwin";
    nixpkgs-unstable.url = "nixpkgs/nixpkgs-unstable";

    home-manager = {
      url = "github:nix-community/home-manager/release-26.05";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    nix-vscode-extensions = {
      url = "github:nix-community/nix-vscode-extensions";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    nur = {
      url = "github:nix-community/nur";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    claude-code = {
      url = "github:sadjow/claude-code-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    nix-claude-code = {
      url = "github:dryvist/nix-claude-code";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.home-manager.follows = "home-manager";
    };

    nix-darwin = {
      url = "github:nix-darwin/nix-darwin/nix-darwin-26.05";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    nix-homebrew.url = "github:zhaofengli/nix-homebrew";
    homebrew-core = {
      url = "github:homebrew/homebrew-core";
      flake = false;
    };
    homebrew-cask = {
      url = "github:homebrew/homebrew-cask";
      flake = false;
    };

    jackielii-tap = {
      url = "github:jackielii/homebrew-tap";
      flake = false;
    };

  };

  outputs = inputs @ {
    self,
    nix-darwin,
    nixpkgs,
    home-manager,
    ...
  }: let
    user = "obvionaoe";

    mkHome = import ./lib/mkHome.nix {inherit user;};
    autoImport = import ./lib/autoImport.nix {inherit (nixpkgs) lib;};
    autoPkgs = import ./lib/autoPkgs.nix {inherit (nixpkgs) lib;};

    # names of subdirectories of `dir`, or [] if `dir` doesn't exist
    listDirs = dir:
      if builtins.pathExists dir
      then
        builtins.attrNames
        (nixpkgs.lib.filterAttrs (_: type: type == "directory") (builtins.readDir dir))
      else [];

    nixosHosts = listDirs ./hosts/nixos;
    darwinHosts = listDirs ./hosts/darwin;

    sharedModules = autoImport ./modules/shared;
    nixosModules = autoImport ./modules/nixos;
    darwinModules = autoImport ./modules/darwin;

    specialArgs = inputs // {inherit user mkHome;};

    darwinSystems = ["aarch64-darwin" "x86_64-darwin"];

    # `nix run github:obvionaoe/flake -- <hostname>` on a fresh Mac with only
    # Nix installed: installs Xcode CLT + Rosetta if missing, backs up any
    # pre-existing /etc files that would conflict with nix-darwin, clones this
    # repo to ~/.flake, and runs the first `darwin-rebuild switch`. See
    # scripts/bootstrap.sh for the actual logic; this just wires up the
    # locked darwin-rebuild binary and repo URL per-system.
    bootstrapApp = system: let
      pkgs = nixpkgs.legacyPackages.${system};
      drv = pkgs.writeShellApplication {
        name = "flake-bootstrap";
        runtimeInputs = [pkgs.git];
        text = ''
          REPO_URL="https://github.com/obvionaoe/flake"
          DARWIN_REBUILD="${nix-darwin.packages.${system}.darwin-rebuild}/bin/darwin-rebuild"
          ${builtins.readFile ./scripts/bootstrap.sh}
        '';
      };
    in {
      type = "app";
      program = "${drv}/bin/flake-bootstrap";
    };
  in {
    formatter =
      nixpkgs.lib.genAttrs nixpkgs.lib.systems.flakeExposed
      (system: nixpkgs.legacyPackages.${system}.alejandra);

    # self-rolled derivations under pkgs/<name>/ (see pkgs/CLAUDE.md), exposed
    # both as an overlay — namespaced under `pkgs.local.<name>` rather than
    # flattened into `pkgs.*`, so a self-rolled package can never shadow or
    # collide with a real nixpkgs attribute of the same name — (wired in via
    # modules/shared/core) and as plain flake packages for `nix build
    # .#<name>` / `nix run .#pkgs-update` without needing a full host eval.
    overlays.default = final: _prev: {local = autoPkgs ./pkgs final;};

    packages = nixpkgs.lib.genAttrs darwinSystems (
      system: let
        # standalone `nix build .#<name>` needs the same allowUnfree policy
        # modules/shared/core applies inside the module system — plain
        # nixpkgs.legacyPackages doesn't have it.
        pkgs = import nixpkgs {inherit system; config.allowUnfree = true;};
      in
        autoPkgs ./pkgs pkgs
    );

    apps = nixpkgs.lib.genAttrs darwinSystems (system: {
      default = bootstrapApp system;
      bootstrap = bootstrapApp system;
      pkgs-update = {
        type = "app";
        program = "${self.packages.${system}.pkgs-update}/bin/pkgs-update";
      };
    });

    #    nixosConfigurations = nixpkgs.lib.genAttrs nixosHosts (hostname:
    #      nixpkgs.lib.nixosSystem {
    #        inherit specialArgs;
    #        modules = sharedModules ++ nixosModules ++ [
    #          { networking.hostName = nixpkgs.lib.mkDefault hostname; }
    #          home-manager.nixosModules.home-manager
    #          ./hosts/nixos/${hostname}
    #        ];
    #      }
    #    );

    darwinConfigurations = nixpkgs.lib.genAttrs darwinHosts (
      hostname:
        nix-darwin.lib.darwinSystem {
          inherit specialArgs;
          modules =
            sharedModules
            ++ darwinModules
            ++ [
              {networking.hostName = nixpkgs.lib.mkDefault hostname;}
              {system.primaryUser = user;}
              {users.users.${user}.name = user;}
              {users.users.${user}.home = "/Users/${user}";}
              home-manager.darwinModules.home-manager
              ./hosts/darwin/${hostname}
            ];
        }
    );
  };
}
