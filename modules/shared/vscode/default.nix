{
  config,
  lib,
  pkgs,
  user,
  nix-vscode-extensions,
  ...
}: let
  cfg = config.modules.vscode;
in {
  options.modules.vscode.enable = lib.mkEnableOption "visual studio code";

  config = lib.mkIf cfg.enable {
    nixpkgs.overlays = [nix-vscode-extensions.overlays.default];

    home-manager.users.${user}.programs.vscode = {
      enable = true;

      package = pkgs.unstable.vscode;

      mutableExtensionsDir = false;

      profiles.default = {
        enableUpdateCheck = false;
        enableExtensionUpdateCheck = false;

        extensions = with pkgs.open-vsx;
          [
            anthropic.claude-code
            editorconfig.editorconfig
            redhat.vscode-yaml
            golang.go
            ms-kubernetes-tools.vscode-kubernetes-tools
            jnoortheen.nix-ide
            # hashicorp.terraform
            opentofu.vscode-opentofu
            redhat.vscode-xml # XML
          ]
          ++ (with pkgs.vscode-marketplace; [
            gruntwork.terragrunt-ls
            tim-koehler.helm-intellisense # Helm
          ]);

        userSettings =
          {
            "claudeCode.preferredLocation" = "panel";
            "claudeCode.useTerminal" = true;
            "diffEditor.ignoreTrimWhitespace" = false;

            "editor.fontFamily" = "'JetBrainsMono Nerd Font', 'monospace', monospace";
            "editor.inlineSuggest.enabled" = true;
            "editor.tabSize" = 2;

            "extensions.ignoreRecommendations" = true;

            "files.autoSave" = "afterDelay";
            "files.trimTrailingWhitespace" = true;
            "files.trimFinalNewlines" = true;
            "files.insertFinalNewline" = true;

            "nix.enableLanguageServer" = true;
            "nix.formatterPath" = "alejandra";
            "nix.serverPath" = "nixd";

            "telemetry.telemetryLevel" = "off";

            "terminal.integrated.fontFamily" = "'JetBrainsMono Nerd Font', 'monospace', monospace";
            "terminal.integrated.scrollback" = 100000;
            "terminal.explorerKind" = "external";
            "terminal.external.osxExec" = "Ghostty.app";

            "update.showReleaseNotes" = false;

            "workbench.editor.empty.hint" = "hidden";

            "[nix]"."editor.defaultFormatter" = "jnoortheen.nix-ide";
            "[nix]"."editor.tabSize" = 2;
          }
          # `pkgs.ghostty` only builds on Linux (see modules/shared/ghostty) —
          # referencing it unconditionally here would force nixpkgs to
          # evaluate an unsupported-platform derivation on Darwin, even
          # though this key is meaningless there (osxExec above covers it).
          // lib.optionalAttrs pkgs.stdenv.isLinux {
            "terminal.external.linuxExec" = "${pkgs.ghostty}/bin/ghostty";
          };
      };
    };
  };
}
