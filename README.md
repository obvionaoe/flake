# ~/.flake

My personal [Nix flake](https://nixos.wiki/wiki/Flakes) for macOS. One repo, two
machines (`air` — personal MacBook, `work` — work MacBook), managed with
[nix-darwin](https://github.com/nix-darwin/nix-darwin) +
[home-manager](https://github.com/nix-community/home-manager). Everything — system
settings, shell, editor, dev toolchains, GUI apps — is declared here and applied
with one command.

## Quickstart

**Fresh Mac, only Nix installed** (any installer — the flag below enables
flakes for this one command, no `nix.conf` editing needed even on a vanilla
install):

```sh
nix run --extra-experimental-features "nix-command flakes" github:obvionaoe/flake -- <hostname>
```

Installs Xcode Command Line Tools and Rosetta 2 if missing, clones this repo to
`~/.flake`, and runs the first `darwin-rebuild switch`. `<hostname>` must match
one of the directories under `hosts/darwin/` (currently `air` or `work`), and
must be run while logged into the macOS account that host declares as
`system.primaryUser` (`obvionaoe` for `air`, `user` for `work`) — the bootstrap
checks this and errors out early on a mismatch.

Git identity is per-host. `air` declares its (public) name and email in the
flake; `work` can't — a real name and employer address must not be committed
here — so it declares only a path, `~/.config/git/identity`, that git pulls in
via `include.path`. The bootstrap prompts for name and email and writes that
file before the first `darwin-rebuild switch`, and leaves it alone if it
already exists. Skipping the prompt just means git has no identity on that
machine until the file is written by hand.

Commits to `~/.flake` itself are always authored as `obvionaoe`, on every host —
`modules/shared/git` adds an `includeIf "gitdir:~/.flake/"` that overrides the
host's default identity for this repo only. So the work machine can manage this
public repo without its commits carrying a work identity.

Safe to re-run: if `~/.flake` already exists (e.g. a previous attempt failed
partway through), it's fetched and hard-reset to `origin/main` rather than
left as-is — the remote always wins, no manual deleting needed. If you're
retrying shortly after a fix was pushed, add `--refresh` so `nix` doesn't
reuse its cached copy of the flake from the last run:

```sh
nix run --refresh --extra-experimental-features "nix-command flakes" github:obvionaoe/flake -- <hostname>
```

**Applying changes after editing the flake:**

```sh
darwin-rebuild switch --flake ~/.flake#<hostname>
```

## What's in here

```
.
├── flake.nix     entry point — discovers hosts + modules, wires everything together
├── lib/          small helpers used by flake.nix (directory auto-discovery, etc.)
├── pkgs/         self-rolled packages for anything not in nixpkgs or Homebrew
├── modules/      one directory per tool/program, each behind its own enable flag
│   ├── shared/     cross-platform (zsh, git, neovim, kubernetes tooling, …)
│   ├── darwin/     macOS-only (Homebrew casks, macOS defaults, skhd, …)
│   └── nixos/      scaffolded for a future Linux machine, not wired up yet
└── hosts/
    └── darwin/   one directory per Mac — its default.nix is the list of
                  modules that machine turns on
```

Adding a new tool or a new machine is almost always "add a directory" — hosts
and modules are discovered automatically from the filesystem, nothing needs to
be registered by hand in `flake.nix` itself.

## Hosts

| Host | Machine | Notes |
|---|---|---|
| `air` | Personal MacBook | Full GUI app surface (Discord, Element, Plex, Mullvad, Steam/Parsec/GeForce NOW), the full dev/DevOps toolchain, and Solo (AI-agent terminal app) |
| `work` | Work MacBook | Leaner — no personal GUI apps or gaming casks, keeps the k8s/terraform/cloud stack plus Slack and a database client |

## Conventions & contributing

This repo is written to be worked on by an AI coding agent as much as by hand —
every directory that has its own conventions carries a `CLAUDE.md` explaining
them (module discovery, the enable-flag pattern, where a new package should
come from, host setup, etc.):

- [`CLAUDE.md`](CLAUDE.md) — repo-wide ground rules, starting here
- [`modules/CLAUDE.md`](modules/CLAUDE.md) — module conventions
- [`pkgs/CLAUDE.md`](pkgs/CLAUDE.md) — self-rolled package conventions
- [`hosts/CLAUDE.md`](hosts/CLAUDE.md) — host conventions

`AGENTS.md` at the repo root points to the same content, for tools that look
for that filename instead.

## Public repository

This repo is published on GitHub, so nothing private — secrets, real names,
employer identifiers, internal hostnames, IP addresses, hardware IDs — is ever
committed here. See `CLAUDE.md` for the full policy.
