{
  config,
  lib,
  ...
}: {
  # No `options` block — modules/shared/claude-code already declares
  # modules.claude-code.enable; this module just reads it and adds the
  # Darwin-only half. See modules/CLAUDE.md's coupled-module split.
  #
  # Claude Desktop (the GUI chat app, distinct from the Claude Code CLI
  # installed by modules/shared/claude-code) has no nixpkgs package on any
  # platform — it's a proprietary Electron app, cask-only, same tier-3
  # case as modules/darwin/spotify.
  config = lib.mkIf config.modules.claude-code.enable {
    homebrew.casks = ["claude"];
  };
}
