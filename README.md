# oh-my-bd

<pre>
       ______     __  __        __    __     __  __        ______     ___
      /\  __ \   /\ \_\ \      /\ "-./  \   /\ \_\ \      /\  == \   /\  __-.
      \ \ \/\ \  \ \  __ \     \ \ \-./\ \  \ \____ \     \ \  __<   \ \ \/\ \
       \ \_____\  \ \_\ \_\     \ \_\ \ \_\  \/\_____\     \ \_____\  \ \____-
        \/_____/   \/_/\/_/      \/_/  \/_/   \/_____/      \/_____/   \/____/
</pre>

[![Version][version-badge]][version-link]
[![CI][ci-badge]][ci-link]
[![License][license-badge]][license-link]

Your personal shell toolkit — wordplay on *oh-my-zsh*, *"oh my bad"*, and *Brandon Diaz*.

A zero-config zsh toolkit: git shortcuts with fuzzy pickers, Docker helpers, project bookmarks, project notes, safe `.env` loading, and tab completion for all of it.

- **Interactive** — every "which one?" question is a fuzzy picker with previews (or a numbered menu without fzf)
- **Discoverable** — type `omb` (or press <kbd>Ctrl+X</kbd> <kbd>Ctrl+O</kbd>) to search every command
- **Completions** — <kbd>Tab</kbd> completes bookmarks, branches, note IDs, stashes, containers, ports…
- **Safe** — destructive commands ask first; `.env` files need your approval; nothing replaces a system command
- **Configurable** — turn plugins on/off, add your own, all outside the install dir so updates never clash
- **zsh on macOS and Linux**, with a smaller fish integration

---

## Install

```bash
sh -c "$(curl -fsSL https://raw.githubusercontent.com/brxndxndiaz/oh-my-bd/main/install.sh)"
```

Then `exec zsh` and type `omb`. To install optional tools without prompts append `_ --yes` after the closing quote (or `_ --no-deps` to skip them).

**Requirements:** zsh, git. **Recommended:** [fzf](https://github.com/junegunn/fzf) 0.48+ (pickers + keybindings), [fd](https://github.com/sharkdp/fd), [bat](https://github.com/sharkdp/bat). Optional: docker, lazydocker, tree, thefuck, lsof.

---

## Find anything

| | |
|---|---|
| `omb` / <kbd>Ctrl+X</kbd> <kbd>Ctrl+O</kbd> | Fuzzy command palette — the chosen command lands on your prompt |
| `omb list [plugin]` | Plugins, or one plugin's commands |
| `omb search <term>` | Search commands |
| `omb cheatsheet` | Everything on one page |
| `<command> help` | Per-command help (`cdc help`, `note help`, `branch help`, `repo help`, …) |

---

## Git

| Command | |
|---|---|
| `switch` | Branch picker (recent first, log preview). Enter switches; type a new name + <kbd>Tab</kbd> to create it. Remote branches are tracked properly |
| `switch <branch>` | Switch, track the remote branch, or create |
| `create <branch>` | Create + switch |
| `branches` | Pick a branch and switch |
| `branch [ls\|new\|rm\|rename\|track]` | Branch manager (`branch rm` with no name opens a picker) |
| `status` | Short status |
| `add` / `add <files>` / `add -i` | Stage all / those files / pick files with diff preview |
| `commit [message]` | Commit (stages everything if nothing is staged; no message opens your editor) |
| `changed` | Changed + untracked files — pick to open in `$EDITOR` |
| `gsync` | Pull `--rebase`, then push |
| `pull` / `push` / `fetch` | Rebase-pull with autostash / push / fetch all + prune |
| `publish` | Push, setting upstream on first push |
| `undo` | Undo last commit, keep changes staged |
| `discard <files>` | Discard changes to just those files |
| `discard` | Discard **all** uncommitted changes (shows them and asks first) |
| `stash` / `unstash [n]` | Stash / pop — picker with diff preview |
| `update` | Rebase onto the remote default branch |
| `rewrite` | `push --force-with-lease` |
| `prune` | Fetch, then pick branches whose remote is gone to delete |
| `log` | Graph log (outside a repo, the system `log` still works) |
| `root` | `cd` to the repo root |
| `repo [root\|open\|name\|main\|url\|pr\|issues]` | Repo summary and links |
| `browse [pr\|issues\|actions\|releases\|file <path>]` | Open repo pages (SSH and HTTPS remotes, GitHub and GitLab) |
| `work` | Branch, dirty state, docker context, `.env` at a glance |
| `tags` / `tag <name> [msg]` | List / create annotated tags |
| `release [patch\|minor\|major]` | Bump the latest `vX.Y.Z` tag |

## Project bookmarks (cdc)

| Command | |
|---|---|
| `cdc` | Pick a bookmark (most recently used first, with directory preview) |
| `cdc <name>` | Jump |
| `cdc add [name] [path]` | Bookmark (defaults: current folder name and path) |
| `cdc rm [name]` / `cdc ls` / `cdc clean` | Remove (picker) / list / drop missing dirs |
| `recent` | Recently used bookmarks |

## Notes

Project-local notes in `notes.md` at the git root — handy context for you and for AI coding agents.

| Command | |
|---|---|
| `note` | Open in `$EDITOR` |
| `note task\|ctx\|bug\|idea\|dec\|code <text>` | Add to a section |
| `note done [id]` | Mark a task done (picker of open tasks) |
| `note wip` | Open tasks |
| `note rm [id]` / `note clear` | Remove an entry / reset (asks) |
| `notes` | Browse and search |

## Autoenv

`cd` into a directory with a `.env` and oh-my-bd offers to load it:

```
[oh-my-bd] Untrusted .env ~/code/api/.env
           sets: DATABASE_URL API_KEY
           Load it? [y]es once / [a]lways / [N]o:
```

- Approval is tied to the file's path **and** content — edit the file and it asks again.
- Variables that could hijack your shell or tools (`PATH`, `LD_*`, `DYLD_*`, `GIT_*`, `NODE_OPTIONS`, …) are never set.
- Leaving the directory restores what was there before.
- `autoenv allow | deny | reload | unload` manage the current directory.

## Docker

| Command | |
|---|---|
| `context` / `ctx [ls\|use [name]]` | Show / list / switch context (picker) |
| `dps` / `dpsa` | Running / all containers |
| `dsh [container]` | Shell into a container (picker) |
| `dlogs [container]` | Follow logs (picker) |
| `clean-containers` / `clean-images` / `clean-all` | Prune |
| `lz` | lazydocker |

**Remote-context guard:** when your Docker context points at another machine (e.g. `ssh://prod`), mutating commands like `docker rm` or `dcdown` ask before running. Read-only commands never ask. Turn it off with `OMBD_DOCKER_GUARD=0`.

**Compose:** `dcup` `dcupd` `dcdown` `dcstop` `dcstart` `dcrestart` `dcbuild` `dcpull` `dcps` `dclogs` `dclogsf` `dcrun` `dcexec [svc]` (picker + shell) `dcl [svc]` (follow logs). See `dcl help`.

## Everyday

| Command | |
|---|---|
| `kill-port [port]` | Stop what's listening (picker of listening ports if no port) |
| `ports` | Listening ports |
| `mkcd <dir>` | `mkdir -p` + `cd` |
| `extract <archive>` | Unpack tar/zip/7z/rar/… |
| `serve [port]` | Serve the current directory over HTTP |
| `gopen <url\|file>` | Open in browser / default app |
| `copy [file]` / `paste` | Clipboard (macOS, X11, Wayland, WSL). `paste` with arguments is the normal `paste` |
| `ll` `la` `l` `cx` `..` `...` `....` `c` | The usual |
| `psg <pattern>` / `top` | Process search / btop or htop if installed |
| `myip` / `sysinfo` | Public + local IP / system summary |
| `tre` / `tf` | Tree without noise / fix last command (thefuck) |

## fzf

| | |
|---|---|
| <kbd>Ctrl+R</kbd> | History search |
| <kbd>Ctrl+F</kbd> | Open the file picker. Press <kbd>Ctrl+F</kbd> again inside it to toggle between Files and Text (requires ripgrep). |
| `ff [scope]` | The same finder as a command — `ff recent` to find the file you just saved somewhere |
| <kbd>Ctrl+T</kbd> | fzf's plain file search |
| <kbd>Alt+C</kbd> | Fuzzy `cd` |
| `vf [query]` | Pick files, open in editor |
| `fcd [query]` | Fuzzy `cd` into a subdirectory |
| `fh [query]` | Pick a past command onto the prompt |

**Files.** Tab cycles through here, home, and recently modified files. Enter inserts the path at your cursor, Ctrl+O jumps to the containing folder, and Ctrl+Space marks several files.

**Text.** Type a literal string inside the picker to see matching lines with a preview. Tab switches between the current directory and Git root when they differ. Enter opens the match at its line in your editor, Ctrl+O jumps to its folder, and Esc returns to your prompt.

---

## Configure

```bash
omb config               # edit ~/.config/oh-my-bd/config.zsh
omb disable docker       # turn a plugin off (omb enable to undo)
omb add work             # create ~/.config/oh-my-bd/plugins/work.zsh — loaded automatically
```

See [`config.example.zsh`](config.example.zsh) for every option. Custom plugins and config live in `~/.config/oh-my-bd`, so `omb update` never touches them.

## Maintain

```bash
omb update      # update right now (shows what changed)
omb doctor      # check dependencies, .zshrc, PATH, plugin syntax, load errors
omb changelog   # recent changes
omb uninstall   # remove (asks whether to keep your config and bookmarks)
```

Updates install themselves: once a day oh-my-bd checks in the background, applies new versions, and every open shell picks them up before its next prompt — no restart. Config changes (`omb config`, `omb enable/disable`, `omb add`) apply the same way. Set `OMBD_AUTO_UPDATE=0` to be notified instead, or `OMBD_SKIP_CHECK=1` to skip checking altogether. Local edits in the install folder are never overwritten automatically.

The first interactive zsh terminal you open each day shows a short command tip. Set `OMBD_TIP_OF_DAY=0` in your oh-my-bd config to turn it off.

## Fish

The installer also hooks into fish when it's installed: aliases, shared `cdc` bookmarks, fzf, and loading of `.env` files you've trusted from zsh.

---

## Contributing

```bash
./test.sh            # run the test suite (tests/run.zsh) against a throwaway $HOME
./test.sh git        # just one group
./test.sh --docker   # in a clean Ubuntu container
```

Commands are listed in [`lib/commands.tsv`](lib/commands.tsv) — add a row when you add a command so it shows up in `omb`, `omb list`, `omb search` and the cheatsheet. See [CHANGELOG.md](CHANGELOG.md).

## Credits

Inspired by [oh-my-zsh](https://github.com/ohmyzsh/ohmyzsh). Built on [fzf](https://github.com/junegunn/fzf), [fd](https://github.com/sharkdp/fd), [thefuck](https://github.com/nvbn/thefuck) and [lazydocker](https://github.com/jesseduffield/lazydocker).

## License

MIT

[version-badge]: https://img.shields.io/github/v/release/brxndxndiaz/oh-my-bd?label=version
[version-link]: https://github.com/brxndxndiaz/oh-my-bd/releases/latest
[ci-badge]: https://github.com/brxndxndiaz/oh-my-bd/actions/workflows/test.yml/badge.svg
[ci-link]: https://github.com/brxndxndiaz/oh-my-bd/actions/workflows/test.yml
[license-badge]: https://img.shields.io/github/license/brxndxndiaz/oh-my-bd
[license-link]: https://github.com/brxndxndiaz/oh-my-bd/blob/main/LICENSE
