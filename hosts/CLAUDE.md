# hosts/ — conventions

## Discovery

`flake.nix` lists the subdirectories of `hosts/nixos` and `hosts/darwin`.
Each directory name becomes both the flake output attribute
(`darwinConfigurations.<name>`) and the default `networking.hostName`.

## NixOS is currently disabled

`hosts/nixos/` and `modules/nixos/` are scaffolded and auto-discovered,
but the `nixosConfigurations` output block in `flake.nix` is entirely
commented out. Adding a `hosts/nixos/<name>/default.nix` alone produces
no flake output — `nixosConfigurations` must be uncommented first (and
the commented block re-verified against the current darwin one, since
they may have drifted). Flag this to the person rather than assuming a
new nixos host will "just work" once the directory exists.

## Adding a new host

Create `hosts/<platform>/<name>/default.nix`, set `nixpkgs.hostPlatform` and
`system.primaryUser` (the macOS account this host is bootstrapped as — see
"The `user` module argument" below), and flip on whichever
`modules.<name>.enable` flags it needs. Remember to `git add` the new
directory — see root `CLAUDE.md`, untracked files are invisible to the flake.

## The `user` module argument

Every module takes `user` as a function argument (alongside `pkgs`, `lib`,
etc.), but it isn't set globally in `flake.nix` — it's derived per host from
that host's own `system.primaryUser` (an inline module in
`darwinConfigurations` in `flake.nix` feeds it back out via
`_module.args.user`). Setting `system.primaryUser` in a host's `default.nix`
is what fixes `user` for every module on that host, including
`home-manager.users.${user}` and `/Users/${user}`.

## Don't duplicate options across hosts

If an option is shared by more than one host, it belongs in a module, not
copy-pasted into each host's `default.nix`.

## `stateVersion`

Don't change `system.stateVersion` / `home.stateVersion` on an existing
host. These are meant to be set once at first install and never bumped
retroactively — flag it to the person instead of "fixing" it.

Note: `home.stateVersion` is currently set once, globally, in
`modules/shared/home-base` rather than per-host. If a second host is ever
added with a different home-manager install history, this may need to
become per-host instead.
