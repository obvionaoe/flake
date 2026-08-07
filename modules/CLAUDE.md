# modules/ — conventions

Applies to `modules/shared/`, `modules/darwin/`, `modules/nixos/`.

## Discovery

`lib/autoImport.nix` lists the subdirectories (and loose `.nix` files) of
each of the three module directories, and every one gets imported into
every relevant host automatically: `shared/` into all hosts, `darwin/`
and `nixos/` into their platform only.

## Platform-only options stay in platform-only directories

Anything referencing `homebrew.*`, `security.pam.*`, or other Darwin-only
(or NixOS-only) options must live under `modules/darwin/` or
`modules/nixos/`, never `modules/shared/` — referencing an option that
doesn't exist on one platform is a hard evaluation error.

## Opt-in, not opt-out

Every module is inert until a host sets `modules.<name>.enable = true;`.
Importing a module costs nothing; a host's `default.nix` is the single
source of truth for what that machine actually has.

**Exception**: `modules/shared/core` and `modules/shared/home-base` have
no `enable` flag at all — they're baseline config (nix settings, the
`pkgs.unstable` overlay, home-manager/xdg wiring) applied unconditionally
to every host. This is intentional, not a bug; don't add an `enable` gate
to them.

## Coupled system + home-manager modules

Some tools need both a system-level piece and a home-manager piece (e.g.
`zsh` needs to be registered as a login shell *and* have its home-manager
config applied). Set both halves behind the same `enable` flag, in the
same file, so the two can never drift out of sync. `zsh` and `ghostty`
are the reference examples — follow that pattern for new dual-purpose
modules.

**Exception — when one half needs a hard darwin-only *outer* option**:
`homebrew.*` (and other nix-darwin outer-system options, as opposed to a
darwin-only *home-manager* option like `launchd.agents`) can't be referenced
from a shared module at all, not even behind `lib.mkIf pkgs.stdenv.isDarwin`
— the option simply isn't declared in NixOS's module system, so assigning to
it is a hard eval error regardless of whether the assignment is conditional.
When a tool's config is genuinely agnostic but its only viable install path
on macOS is a Homebrew cask, split it: the agnostic config stays in
`modules/shared/<name>` and declares the `enable` option; a
`modules/darwin/<name>` module reads that same `config.modules.<name>.enable`
(without redeclaring it) and sets `homebrew.casks` behind it — no example
currently lives in the tree (`mullvad-browser`/`vlc` are cask-only with no
agnostic config to split out in the first place), but reach for this the day
a tool needs both.

## Cross-module defaults

A module can default-enable another from inside its own `config` block,
e.g. `modules/shared/claude-code` sets `modules.rtk.enable =
lib.mkDefault true;`. Use `lib.mkDefault` (not a plain assignment) so a
host can still override it explicitly.

## `pkgs.unstable`

`modules/shared/core` overlays `nixpkgs-unstable` as `pkgs.unstable`, for
when a module needs a newer package than the pinned `nixpkgs` provides
(see `modules/shared/vscode`'s `pkgs.unstable.vscode`).

`modules/shared/core` also overlays every self-rolled derivation under
`pkgs/<name>/` (see `pkgs/CLAUDE.md`) as `pkgs.local.<name>` — same
mechanism, different source directory (namespaced under `local` so these can
never collide with a real nixpkgs attribute).

## Where should a package come from?

When adding a new program, prefer in this order:

1. **home-manager `programs.<name>`** — if home-manager ships a module for
   it, use that. It gets you declarative config (dotfiles, settings) for
   free, not just the binary.
2. **nixpkgs** (`home.packages` / `environment.systemPackages`) — if there's
   no `programs.*` module but the package exists in nixpkgs and builds on
   the target platform, use it. Verify platform support with an actual
   `nix eval --system aarch64-darwin nixpkgs#<pkg>.outPath` rather than
   trusting `meta.platforms` alone — a package can list `darwin` under
   `meta.platforms` while excluding it via `meta.badPlatforms` (this is why
   `mullvad-vpn` below is a Homebrew cask, not a nixpkgs package, despite
   `meta.platforms` saying otherwise).
3. **Homebrew cask/formula** — only when neither of the above works. This
   is normal for macOS GUI apps needing OS-level integration nixpkgs can't
   provide (system/network extensions, code-signing, licensing
   installers) — e.g. `plex`, `ungoogled-chromium`, `mullvad-vpn`. Also
   falls here when the nixpkgs derivation exists but is currently unusable
   for some other reason — `spotify` is the current example: nixpkgs'
   copy builds fine, but home-manager's app-copy step corrupts its code
   signature, so it's a cask instead (see `modules/darwin/spotify` for the
   specifics). These are worth rechecking periodically, since the
   underlying blocker can get fixed upstream —
   `bitwarden` did exactly that round-trip: it was a cask because nixpkgs'
   `bitwarden-desktop` bundled an insecure/EOL Electron and refused to
   build, until nixpkgs-unstable picked up a newer Electron and it moved
   back to tier 2 (see `modules/shared/bitwarden`).
4. **Self-rolled derivation in `pkgs/<name>/`** — last resort, when nothing
   above works at all: no nixpkgs package, no usable cask (e.g. a proprietary
   app only distributed as a signed vendor `.dmg`/`.zip`, like `soloterm`).
   See `pkgs/CLAUDE.md` for the shape (`default.nix` + `source.json` +
   optional `update.sh`) and the `pkgs-update` command that keeps these
   current. **A module itself must never contain `mkDerivation`, `fetchurl`,
   or `fetchFromGitHub`** — that packaging logic lives in `pkgs/<name>/`, and
   the module just references `pkgs.local.<name>` (exposed via the overlay
   wired into `modules/shared/core`) like it would any other package.

Each program still gets its own module (see "New module template" below)
that declares whichever tier it needs, gated behind its own `enable` flag —
don't add a flat package list to `modules/darwin/homebrew`. See
`modules/darwin/skhd` or `modules/darwin/spotify` for the homebrew-cask
shape, `modules/shared/bitwarden` or `modules/shared/obsidian` for the
nixpkgs/home-manager shape, and `modules/darwin/soloterm` for the tier-4
shape (option + install only — the derivation itself lives in
`pkgs/soloterm/`).

Note: on older home-manager releases, nixpkgs-installed GUI apps landed in
`~/Applications/Home Manager Apps` as symlinks into `/nix/store`, which
Spotlight/Launch Services don't reliably index (the store volume itself is
typically excluded from indexing). As of home-manager 25.11+ (this flake's
pin), `targets.darwin.copyApps` is on by default and copies real `.app`
bundles there instead of symlinking, fixing this natively — no extra module
needed (a `mac-app-util` module existed here for the old symlink-trampoline
approach; it was dropped once `copyApps` made it verified dead weight). So
prefer nixpkgs/home-manager for GUI apps per the tiering above rather than
reaching for a Homebrew cask just to work around Spotlight.

`modules/darwin/homebrew` also sets `homebrew.onActivation.cleanup = "zap"`,
so any formula/cask/tap installed on the machine but not declared in some
module gets fully removed (app + support files + preferences) on the next
`darwin-rebuild switch`. Anything installed by hand for one-off testing
needs to be added to a module first, or it will be zapped on the next
rebuild.

## Concern-bundle modules

Some tools cluster into one cohesive toolchain around a single concern —
Kubernetes, Terraform — rather than being independently useful on their own.
For these, don't make one module per binary; bundle the whole concern into a
single module with a core `enable` flag plus grouped sub-flags for optional
tiers (e.g. `.linting`, `.extras`), composed with `lib.mkMerge`:

```nix
{ config, lib, pkgs, user, ... }:
let cfg = config.modules.kubernetes; in {
  options.modules.kubernetes = {
    enable        = lib.mkEnableOption "kubernetes toolchain";
    linting.enable = lib.mkEnableOption "k8s manifest linters";
    extras.enable  = lib.mkEnableOption "niche k8s tools";
  };
  config = lib.mkMerge [
    (lib.mkIf cfg.enable                         { /* core packages + aliases */ })
    (lib.mkIf (cfg.enable && cfg.linting.enable) { /* linters */ })
    (lib.mkIf (cfg.enable && cfg.extras.enable)  { /* niche tools */ })
  ];
}
```

See `modules/shared/kubernetes` (core + `.linting` + `.extras`) and
`modules/shared/terraform` (core + `.linting`) for worked examples,
including large ported alias sets.

**When to bundle vs. keep separate**: bundle when the tools only make sense
*together*, as one toolchain around a concern (kubectl + kubectx + helm +
linters all serve "using Kubernetes"). Keep tools in their own single-purpose
module when each is independently useful and independently configured (git,
zsh, ghostty) — don't fold those into a bundle just because they're used
together on one machine.

**Placement**: concern-bundles are almost always platform-agnostic (the
toolchain itself doesn't care about the host OS), so default them to
`modules/shared/` like any other agnostic module — see "Platform-only
options" above. This also means a future NixOS host gets the whole bundle
for free via the same `enable` flags.

## New module template

```nix
{ config, lib, user, ... }:
let cfg = config.modules.<name>; in
{
  options.modules.<name>.enable = lib.mkEnableOption "<name>";
  config = lib.mkIf cfg.enable { /* ... */ };
}
```

Read an existing module (e.g. `modules/shared/zsh/`) before adding a new
one, to match the established shape. Keep modules small and
single-purpose — one program or concern per module, named after what it
configures.
