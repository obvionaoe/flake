# Migrating to `programs.claude.configDir`

Background for `modules/shared/claude-code/default.nix`'s `configDir =
".config/claude";` — why it's safe, what it actually touches, and the
by-hand steps needed on every machine before a rebuild with this setting
lands, so no session/project history or MCP config gets stranded.

## Where this option came from

`programs.claude.configDir` is upstream `dryvist/nix-claude-code`, not a
fork. It shipped in two PRs, both merged to that repo's `main`:

- **#177** ("support CLAUDE_CONFIG_DIR via programs.claude.configDir") —
  the feature itself. Authored by this repo's own maintainer
  (`obvionaoe`). Adds the option (home-relative, default `.claude`) and
  threads it through every path the module writes, exporting
  `CLAUDE_CONFIG_DIR` to match so the module and the real `claude` binary
  can't disagree about where the config tree lives. At the default value
  the output is byte-for-byte unchanged (enforced by a regression check),
  so adopting the option only matters once you set it to something else.
- **#223** ("close the remaining configDir gaps and cover the
  assertions") — a hardening follow-up:
  - Fixed a latent bug in `flake/checks/marketplace-delivery.nix`: it
    hard-coded `.claude` in its marketplace-cleanup glob instead of
    deriving it from `configDir`, which made that check's negative
    assertion vacuously pass for anyone on a relocated `configDir` — it
    was testing nothing.
  - `configDir` now rejects the glob metacharacters `* ? [ ]`, since the
    value is interpolated unquoted into a `case` pattern
    (`MARKETPLACES_GLOB`) that decides what activation cleanup deletes —
    a metachar there would silently widen the match instead of naming a
    path.
  - Added the first real test coverage for the `configDir` assertions
    (none existed before).

  Our value, `.config/claude`, has no glob characters, so #223's new
  validation doesn't reject it — this just confirms we're not hitting
  the bug #223 fixed or the gap it closed.

A fork pin (`github:obvionaoe/nix-claude-code/feat/config-dir`) was used
temporarily while #177 was still unmerged; it's gone now that both PRs
have landed upstream, so `flake.nix` stays on plain
`github:dryvist/nix-claude-code`.

## What Nix actually manages under `configDir`

Reading the module source (`modules/core.nix`, `modules/components.nix`,
`modules/claude-json.nix`, `modules/orphan-cleanup.nix`) narrows this down
a lot — Nix only ever touches:

- `settings.json` — merged at activation time into a real, writable file
  (not a symlink, so Claude Code's own runtime mutations to it aren't
  blocked).
- `commands/`, `agents/`, `skills/`, `rules/` — individual `.md` files,
  symlinked in with `force = true`.
- `plugins/marketplaces/*` — symlinked directories for Nix-managed
  marketplaces.
- The statusline script.
- Orphan-cleanup only prunes *broken* or *stale-generation* symlinks
  inside those same component/marketplace dirs. It never touches
  anything else.

Everything else under `~/.claude` — `projects/`, `sessions/`,
`shell-snapshots/`, `backups/`, `cache/`, `file-history/`, `paste-cache/`,
`plans/`, `session-env/`, `telemetry/`, credentials, `history.jsonl`, a
hand-written top-level `CLAUDE.md`/`RTK.md`, etc. — is Claude Code's own
runtime state. Nix doesn't know it exists and never deletes or
reorganizes it.

## The part that's easy to miss: `~/.claude.json`

`~/.claude.json` is a **separate top-level file**, a sibling of
`~/.claude`, not inside it (`modules/claude-json.nix`'s `claudeJsonPath`
logic). It holds MCP server registrations, remote-control pairing state,
and the trusted-project list.

At the default `configDir`, upstream keeps this file at
`$HOME/.claude.json`. Once `configDir` is non-default, upstream's own
(undocumented — see
[anthropics/claude-code#3833](https://github.com/anthropics/claude-code/issues/3833))
behavior moves it *inside* the new directory, and the module mirrors
that. So migrating means moving **both** `~/.claude` and `~/.claude.json`
— forgetting the second one silently drops MCP/remote-control config even
though all of `~/.claude`'s contents came across fine.

## Why a plain rebuild would look like data loss

`CLAUDE_CONFIG_DIR` is what redirects the `claude` binary's entire config
tree. Nix only ever *exports* that variable once `configDir != ".claude"`
— it does not migrate any existing content there itself. Flip the
setting and rebuild without moving anything first, and `claude` just
starts a fresh, empty `~/.config/claude` and treats it as a brand-new
install. Your old data isn't deleted — it's still sitting untouched at
`~/.claude` — but it's invisible to the binary until moved in by hand.

## Migration steps, per machine

This is local filesystem state, not something `git pull` carries across
— run this on **every** machine independently, including a second time
on `work` after it picks up the module change.

```bash
# 1. Quit every Claude Code session/process first — this is live state.
#    Confirm nothing's left:
pgrep -fl claude

# 2. Move both pieces — the directory AND the sibling file — together,
#    before the rebuild that flips configDir, so home-manager merges its
#    settings.json/.claude.json into the already-relocated files instead
#    of creating fresh empty ones.
mkdir -p ~/.config
mv ~/.claude ~/.config/claude
mv ~/.claude.json ~/.config/claude/.claude.json

# 3. Rebuild.
darwin-rebuild switch --flake ~/.flake#<host>
```

Afterwards, open a fresh shell (to pick up the new `CLAUDE_CONFIG_DIR`)
and confirm `claude` still sees old sessions/projects, and that MCP
servers / remote-control pairing survived (the `.claude.json` move).

If `~/.config/claude` already exists from an earlier partial attempt,
reconcile that first — the `mv` into an existing directory target would
nest the old tree inside it (`~/.config/claude/.claude`) instead of
replacing it.
