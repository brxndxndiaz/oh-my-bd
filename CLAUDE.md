# Maintaining oh-my-bd

Notes for whoever (human or agent) picks up maintenance.

## Layout
- `lib/core.zsh` — entry point sourced from `.zshrc`. Loads `utils.zsh`, the user config, built-in plugins (fixed order), custom plugins, then completions. Everything runs inside anonymous functions so nothing leaks into the user's shell.
- `lib/utils.zsh` — shared helpers: `ombd_has`, `ombd_confirm`, `ombd_pick` (fzf or numbered menu), `ombd_open`, `ombd_remote_web_url`, `ombd_default_branch`, `ombd_interactive`, color vars `OMBD_C_*`.
- `lib/commands.tsv` — the single list of commands (plugin, command, description). Drives `omb` palette, `omb list/search/cheatsheet`. **Add a row for every new command.**
- `lib/completions.zsh` — all zsh completions.
- `plugins/*.zsh` — built-in plugins. `bin/oh-my-bd` — the CLI. `install.sh` — POSIX sh (it's run via `sh -c`).
- User data lives outside the repo: `~/.config/oh-my-bd/{config.zsh,plugins/,autoenv-trusted,update-check}`, `~/.cdc_dirs`.

## Live reload
- Open shells re-source `core.zsh` before the next prompt whenever `$OMBD_CONFIG_DIR/reload` changes. The CLI writes it via `signal_reload` (`manual`) and unattended updates write it with `auto`. Any CLI command that changes what gets loaded must call `signal_reload`.
- On reload, everything plugins defined (tracked in `_ombd_owned_funcs` / `_ombd_owned_aliases`) is removed first, including hooks and zle widgets pointing at it, then plugins load again.
- So **plugins must be safe to source twice**: keep runtime state with `typeset -g x="${x-default}"` / `(( ${+x} )) || typeset -gA x`, and skip one-time startup work when `$_ombd_reloading` is set.
- `omb update --auto` (run by the background check) only fast-forwards a clean install; anything else falls back to the "Update available" notice.

## Rules of thumb
- Never shadow a real system command. If a name collides (`log`, `paste`, `top`), fall through to `command <name>` when used non-interactively or with arguments.
- Anything destructive goes through `ombd_confirm`. Tests use `OMBD_ASSUME_YES=1`.
- Pickers are called inside `$(...)` with a pipe on stdin — use `ombd_pick` / `ombd_interactive`, never check `-t 0`/`-t 1` for picker availability.
- Define plugin functions as `function name {` (not `name() {`) so a pre-existing alias can't break loading.
- Use `"${(@f)var}"` (not `${(f)var}`) when empty lines matter, e.g. fzf `--expect` output.
- `install.sh` must pass `dash -n` and `shellcheck --shell=sh`.

## Testing
- `zsh tests/run.zsh [group]` — throwaway `$HOME`, ~115 checks, runs in CI on Linux and macOS.
- Every bug fix gets a test in the matching group.
- For interactive changes, smoke test in tmux with a real fzf (>= 0.48 and the distro 0.44 fallback).

## Releasing
1. Update `VERSION` and add a `## X.Y.Z` section to `CHANGELOG.md`.
2. Merge to `main`, then tag `vX.Y.Z` and push the tag. CI checks `VERSION` matches and creates the GitHub release from the changelog section.
