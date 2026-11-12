# Changelog

## 2.2.0

### Changed
- **Updates are seamless.** The daily background check installs fast-forward updates by itself, and every open shell reloads oh-my-bd before its next prompt — no `omb update`, no `exec zsh`. You see one line: `[oh-my-bd] updated 2.2.0 → 2.2.1 · omb changelog`. Set `OMBD_AUTO_UPDATE=0` to only be notified.
- `omb update`, `omb config`, `omb enable/disable` and `omb add/remove` take effect in the current shell and every other open one immediately. Disabling a plugin removes its commands, hooks and key bindings live; custom plugins and your config are reloaded too.
- A reload never swaps in code that doesn't parse — it keeps the running version and says which file is broken.
- `omb update` is stricter: it only fast-forwards, and refuses (leaving everything untouched) on local edits, local commits, divergence or a detached checkout. Automatic updates follow the same rules silently and fall back to the "Update available" notice.

### Added
- Text search in the <kbd>Ctrl+F</kbd> picker: press <kbd>Ctrl+F</kbd> again to switch between Files and Text (needs ripgrep). Enter opens the match at its line in your editor; Tab switches between the current folder and the git root.
- A short command tip in the first terminal of the day (`OMBD_TIP_OF_DAY=0` to turn off).
- The command palette only lists commands from enabled plugins.
- `omb doctor` checks for ripgrep. Autoenv restores variables that weren't exported before exactly as they were, and handles symlinked folders and repeated keys.

Upgrading from 2.1 or earlier needs one last restart of terminals that were already open — older shells can't reload themselves.

## 2.1.0

### Added
- <kbd>Ctrl+F</kbd> is now a scoped file finder: <kbd>Tab</kbd> cycles **here** → **everywhere** (home folder, skipping `node_modules`, caches, `Library`, …) → **recent** (files changed in the last 3 days, newest first — for finding the file you just saved in the wrong place). <kbd>Ctrl+O</kbd> jumps to the selected file's folder. Works without `fd` and on fzf 0.44.
- `ff [here|everywhere|recent]` — the same finder as a command.
- `OMBD_RECENT_DAYS` sets the window for the recent scope.

## 2.0.0

A big maintenance release: bug fixes, safer defaults, fuzzy pickers everywhere, and tab completion.

### Breaking changes
- `sync` is now **`gsync`**. The old name shadowed the system `sync` command, so running it before ejecting a drive pushed your current branch instead.
- `discard` with no arguments now **asks first** (it runs `git reset --hard`). `discard <files>` only touches those files — before, the file argument was ignored and every change was thrown away.
- `dir`, the `~` alias and the `top`/`paste` aliases are gone. `top` and `paste` are now functions that pass through to the real commands when given arguments.
- Notes are stored at the **git root** (`notes.md`) instead of the current directory, so `note` works from any subfolder.
- Custom plugins live in `~/.config/oh-my-bd/plugins` (`omb add <name>`), not inside the install dir.
- Autoenv asks before loading a `.env` it hasn't seen, and never sets `PATH`, `LD_*`, `DYLD_*`, `GIT_*` and similar variables.
- `omb update` migrates your `.zshrc` to a `# >>> oh-my-bd >>>` block (backup kept as `.zshrc.omb-backup`).

### Fixed
- Autoenv never worked in zsh: variables were exported in a subshell. Values containing `#` or `=` were also cut off.
- Picking a remote branch (`origin/feature`) in `switch`/`branches` created a local branch literally named `origin/feature`; the bare `origin` entry is gone from the list.
- `cdc` picker chopped a trailing capital `A` from paths (`~/TeamA` → `~/Team`); bookmark names with regex characters could match the wrong bookmark.
- `omb uninstall` failed on Linux (`sed -i ''`), removed nothing on macOS, could delete your own `PATH` line, and left the `omb` symlink and fish config behind.
- The one-line installer runs under `sh`: dependency checks always "passed" under dash and optional-tool prompts never worked. The installer is now POSIX sh.
- `omb add` plugins were never loaded.
- Loading oh-my-bd overwrote oh-my-zsh's `$plugins` and leaked other variables.
- The daily update check blocked shell startup on `git fetch` (and retried on every new shell when offline). It now runs in the background.
- `omb update` silently discarded local edits; it now asks and stashes them.
- `repo open`/`pr`/`issues` and `browse` produced broken URLs for SSH remotes, hardcoded `main`, and only worked on macOS.
- `release` called a `release.sh` that doesn't ship; `recent` used `tac` (missing on macOS); `note help` created `notes.md`; `note wip` listed every entry; `omb search` printed stray `]`.
- fzf keybindings errored on fzf < 0.48 (Ubuntu/Debian packages); now falls back to the distro's key-binding files.
- The Docker wrapper prompted on every command whenever the context wasn't named `default` (e.g. Docker Desktop's `desktop-linux`).

### Added
- `omb` command palette (also <kbd>Ctrl+X</kbd> <kbd>Ctrl+O</kbd>) — fuzzy-search every command and drop it on your prompt.
- Tab completion for `omb`, `cdc`, `note`, `switch`, `branch`, `repo`, `browse`, `unstash`, `release`, `discard`, `add`, `context`, `dsh`, `dlogs`, `dcexec`, `kill-port`, `autoenv`.
- Pickers (fzf with previews, or a numbered menu without fzf): `switch` (Tab creates a branch), `branches`, `branch rm`, `add -i`, `changed`, `unstash`, `prune`, `cdc`, `cdc rm`, `recent`, `note done`, `note rm`, `kill-port`, `context use`, `dsh`, `dlogs`, `dcexec`.
- `omb config`, `omb enable/disable <plugin>`, `omb edit <plugin>`, `omb changelog`, a much more thorough `omb doctor`.
- `cdc add` with no arguments, `cdc ls`, `cdc clean`; bookmarks are ordered by most recent use.
- `note done`, `note reopen`; `autoenv allow|deny|reload|unload`.
- `mkcd`, `extract`, `serve`, `dsh`, `dlogs`, `fh`; `vf` and `fcd` actually open/cd now.
- Docker guard only prompts for mutating commands on *remote* contexts.
- Real test suite (`tests/run.zsh`, 115 checks) running on Linux and macOS in CI; release job checks `VERSION` matches the tag.

## 1.2.0 and earlier

See the [GitHub releases](https://github.com/brxndxndiaz/oh-my-bd/releases).
