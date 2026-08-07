# pkgs/ — conventions

Self-rolled Nix derivations: packages that exist in neither nixpkgs nor as a
usable Homebrew cask, so this flake builds them itself (tier 4 of
`modules/CLAUDE.md`'s "Where should a package come from?" list). `soloterm` —
a proprietary macOS `.app` shipped only as a vendor `.dmg` — is the reference
example.

## Discovery

Every subdirectory of `pkgs/` containing a `default.nix` becomes
`pkgs.local.<dirname>` on every host, automatically — `lib/autoPkgs.nix` scans
this directory the same way `lib/autoImport.nix` scans `modules/`, and
`modules/shared/core` wires the result in as an overlay
(`self.overlays.default`), namespaced under `local` so a self-rolled package
can never shadow or collide with a real nixpkgs attribute of the same name.
Adding a package here is "add a directory", same as adding a module or a
host — **and it needs `git add`ing before the flake can see it**, exactly
like a new module or host.

## Modules never contain a derivation

A `modules/**/default.nix` must only declare the `enable` option and install
the package (`home.packages = [pkgs.local.<name>];` or similar) — it must never
contain `mkDerivation`, `fetchurl`, `fetchFromGitHub`, or any other
packaging logic. If a module needs a from-scratch derivation, that derivation
belongs here, referenced from the module as `pkgs.local.<name>`.

## Package directory shape

```
pkgs/<name>/
├── default.nix   # the derivation — callPackage-able, takes standard nixpkgs args
├── source.json   # {"version", "url", "hash"} — the vendor's mutable bits
└── update.sh     # optional: makes this package eligible for `pkgs-update`
```

`default.nix` reads `source.json` with `lib.importJSON` rather than hardcoding
`version`/`url`/`hash` inline. This split exists so `pkgs-update` (see
`pkgs/pkgs-update/`) never has to edit or regex actual Nix source — it only
ever rewrites this one JSON file, which it fully controls the shape of.

## The `update.sh` contract

Any package that wants automatic updates via `pkgs-update <name>` /
`pkgs-update --all` drops an executable `update.sh` next to its `default.nix`.
Requirements:

- No arguments, no reliance on cwd — resolve its own directory via
  `${BASH_SOURCE[0]}` if it needs to.
- Prints exactly one line of JSON to stdout on success:
  `{"version": "...", "url": "..."}` — the latest upstream version and its
  download URL. Nothing else goes to stdout.
- Exits non-zero with a message on stderr on any failure (network error,
  page layout changed, version not found, etc). The driver
  (`scripts/pkgs-update.sh`) treats a non-zero exit as "skip this package,
  keep going" — it never writes `source.json` on failure.
- Never touches `source.json` itself, and never prefetches/hashes anything —
  the driver does that (`nix store prefetch-file`) after comparing the
  reported version against the current one, so a package with an unreachable
  or unstable "latest version" source degrades to "no bump", not a corrupt
  config.

A package with **no** `update.sh` (e.g. `pkgs/pkgs-update` itself) is simply
skipped by `--all` and reported as unknown by name — that's fine, not every
self-rolled derivation needs a scriptable update source.

Some vendors (soloterm included) have no appcast/releases API at all — see
`pkgs/soloterm/update.sh` for scraping a vendor page as a last resort. This is
inherently brittle and expected to occasionally need touching up when the
vendor changes their page; that's an acceptable failure mode for this tier of
package.
