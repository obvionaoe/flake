{
  config,
  lib,
  ...
}: let
  cfg = config.modules.agents;
in {
  # Thin wrapper — the only agent-harness module a host should enable
  # directly. `modules.claude-code` and `modules.opencode` each own their
  # actual package/config wiring (nix-claude-code home-manager surface,
  # opencode's programs.opencode, any future harness's equivalent) and stay
  # off unless something turns them on; this module is the "something",
  # same cross-module-default idiom modules/shared/claude-code already uses
  # for modules.rtk (see modules/CLAUDE.md, "Cross-module defaults"), just
  # one level up. Keeping this file free of any harness-specific config is
  # deliberate: it's what keeps it from bloating as more harnesses get added
  # here later — each new one gets its own module plus one more line below,
  # not more surface area in this file.
  options.modules.agents = {
    enable = lib.mkEnableOption "AI coding agent harnesses (Claude Code, opencode)";

    claude.enable = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Install and configure Claude Code.";
    };

    opencode.enable = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Install and configure opencode.";
    };
  };

  config = lib.mkIf cfg.enable {
    modules.claude-code.enable = lib.mkDefault cfg.claude.enable;
    modules.opencode.enable = lib.mkDefault cfg.opencode.enable;
  };
}
