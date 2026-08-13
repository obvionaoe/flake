# TODO

## zsh-min-plus: `_update_gcp_profile` leaks a shell error every prompt

`_update_gcp_profile` in `obvionaoe/zsh-min-plus` (`min-plus.zsh`) is
registered as a `precmd` hook, so it runs before every prompt:

```zsh
precmd_functions+=(_update_gcp_profile)
_update_gcp_profile() {
  [[ $_min_has_gcloud -ne 1 ]] && return

  local active_config
  active_config="$(<~/.config/gcloud/active_config 2>/dev/null)"
  ...
}
```

It only guards on whether the `gcloud` CLI is *installed*, not on whether
`gcloud` has actually been initialized. On a host with `google-cloud-sdk`
installed (via this flake's `modules.cloud`) but no `gcloud init`/`auth
login` ever run, `~/.config/gcloud/active_config` doesn't exist, and the
read fails on every prompt:

```
_update_gcp_profile:3: no such file or directory: /Users/user/.config/gcloud/active_config
```

The `2>/dev/null` doesn't suppress it because of redirect ordering: zsh
applies `<file` before `2>/dev/null` takes effect, so a failed `open()` on
`<file` reports to the original stderr before the redirect to `/dev/null`
is even in place — later redirects in the same list never apply once an
earlier one fails.

**Fix belongs in `obvionaoe/zsh-min-plus`, not this repo** — this flake
just pulls that plugin in via antidote (`modules/shared/zsh`). Either:

- reorder the redirect: `2>/dev/null` before `<~/.config/gcloud/active_config`, or
- guard first: `[[ -r ~/.config/gcloud/active_config ]] || return`

before attempting the read.
