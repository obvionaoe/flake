# CLAUDE.md

Guidance for Claude (or any AI assistant) working in this repository.

## What this repo is

A single Nix flake that builds multiple machine configurations — both
NixOS and nix-darwin (macOS) — from one codebase. Hosts and program
modules are discovered automatically from the directory structure, so
adding a new machine or a new tool is almost always "add a directory",
not "edit the flake."

## Structure

```
.
├── flake.nix              # entry point: discovers hosts + modules, wires everything together
├── lib/
│   ├── autoImport.nix      # scans a directory, returns import paths for every entry in it
│   ├── autoPkgs.nix        # scans pkgs/, returns an overlay-able attrset of packages
│   └── mkHome.nix          # helper for one-off, host-specific home-manager tweaks
├── pkgs/                   # see pkgs/CLAUDE.md for conventions
│   └── <name>/             # a self-rolled derivation, exposed as pkgs.local.<name> everywhere
├── modules/                # see modules/CLAUDE.md for conventions
│   ├── shared/<name>/      # cross-platform modules (imported into every host)
│   ├── darwin/<name>/      # macOS-only modules (imported only into darwinConfigurations)
│   └── nixos/<name>/       # Linux-only modules (imported only into nixosConfigurations)
└── hosts/                  # see hosts/CLAUDE.md for conventions
    ├── darwin/<hostname>/  # one folder per Mac; default.nix is that host's entrypoint
    └── nixos/<hostname>/   # one folder per NixOS machine
```

## Public repository — no private data, ever

**This repo is published publicly on GitHub.** Anything committed here is
permanently visible (git history included), so nothing private may ever land
in it. This is a hard rule, not a style preference — flag a violation instead
of committing it, even if asked to "just add it quickly."

Never commit, even temporarily:
- Secrets, tokens, API keys, private keys, or credentials of any kind.
- **Real names** or **personal/employer email addresses** — the one exception
  is the intentional public identity, declared by the `air` host as
  `modules.git.userName` / `modules.git.userEmail`: `obvionaoe` /
  `obvionaoe@protonmail.com`. No other name or address belongs here,
  including any employer identity — the `work` host's git identity therefore
  goes through `modules.git.identityFile` instead (see below). Commits to
  `~/.flake` are pinned to the public identity on *every* host by an
  `includeIf "gitdir:~/.flake/"` in `modules/shared/git`, so a work machine
  can't accidentally author a commit here under its own identity.
- Internal/employer hostnames, domains, or service URLs (e.g. anything like
  `*.internal`, a company's VPN/monitoring/git-mirror hosts).
- IP addresses (homelab, cloud instances, VPNs) or SSH host maps that reveal
  network topology.
- Hardware identifiers: disk/LUKS UUIDs, serial numbers, MAC addresses.

If a module genuinely needs a sensitive value, don't inline it — use a proper
secrets tool (`sops-nix`, `agenix`) or keep the value in a file outside this
repo, and ask before adding either. `modules/shared/git`'s `identityFile` is
the worked example of the second approach: the host declares only a *path*
(`~/.config/git/identity`), git pulls it in with `include.path`, and
`scripts/bootstrap.sh` prompts for the values and writes that file on first
run — the repo never sees them. When porting *anything* in from an old,
private version of this config, scrub it for the above first — the source
material is not held to this rule and cannot be trusted to be clean.

## Ground rules (apply everywhere in this repo)

- **Never run `darwin-rebuild`, `nixos-rebuild`, `nix build`, `home-manager switch`,
  or any other command that builds/activates/switches system state.** Always hand
  the exact command back to the person to run themselves — they need to review
  the diff and be the one applying changes to their own machine.
- **Git-tracked files only**: Nix flakes only see files tracked by git. A new
  host or module directory is invisible to the flake until it's at least
  `git add`ed (staged is enough, doesn't need to be committed) — this fails
  silently, with no error, so call it out whenever you add one.
- Don't hardcode secrets, tokens, or private keys into any file in this repo.
  Ask before adding anything sensitive, and prefer a proper secrets tool
  (e.g. `sops-nix`, `agenix`) over inlining a value. See "Public repository"
  above — this repo's public status makes this rule non-negotiable.
- Don't silently rename the `user` variable, a hostname, or a module's option
  name — these are referenced in multiple places and a rename needs to be
  applied consistently and called out explicitly.
- **Verifying a change is safe to do yourself, without building anything**:
  `nix eval <target>` (e.g.
  `nix eval .#darwinConfigurations.<host>.config.home-manager.users.<user>.home.packages
  --apply 'pkgs: map (p: p.pname or p.name or "?") pkgs'`) and
  `nix flake check --no-build` both evaluate the flake — including running
  every module through the option system — without building or activating
  anything, so they're fine to run freely to confirm a change type-checks or
  a package resolves. Plain `nix flake check` (no `--no-build`) and `nix
  build` *do* build derivations and fall under the rule above — hand those
  back instead.

## More detail

- `modules/CLAUDE.md` — module discovery, the enable-flag pattern (and its
  two exceptions), coupled system+home-manager modules, cross-module
  defaults, the `pkgs.unstable` overlay, and the module template.
- `pkgs/CLAUDE.md` — when a package belongs here instead of a module, the
  `default.nix`/`source.json`/`update.sh` shape, and the `pkgs-update`
  command that refreshes these to their latest upstream version.
- `hosts/CLAUDE.md` — host discovery, adding a new host, `stateVersion`
  rules, and why NixOS hosts don't currently build (disabled flake output).
