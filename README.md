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

A zero-config toolkit for developers. Git shortcuts, Docker helpers, project bookmarks, notes, and general QoL commands — all in one.

- **Zero-config** — runs with sane defaults
- **Cross-shell** — bash, zsh, fish, dash
- **Cross-platform** — macOS and Linux
- **Plugin-based** — only loads what's available
- **AI-friendly** — project-local notes for context

---

## Quick Start

```bash
sh -c "$(curl -fsSL https://raw.githubusercontent.com/brxndxndiaz/oh-my-bd/main/install.sh)"
```

Restart your shell when done.

---

## Features

### Git

| Command | Description |
|---------|-------------|
| `status` | Git status |
| `add` | Stage all changes |
| `commit <msg>` | Commit (auto-stages if empty) |
| `switch <branch>` | Switch branch |
| `create <branch>` | Create + switch |
| `sync` | Fetch + rebase + push |
| `undo` | Undo last commit (keep changes) |
| `discard` | Undo last commit (discard changes) |
| `stash` / `unstash` | Stash management |
| `log` | Pretty log graph |
| `branches` | List all branches |

### Docker

| Command | Description |
|---------|-------------|
| `context ls` | List contexts |
| `context use <name>` | Switch context |
| `context` | Show current |
| `dps` | Show running containers |
| `dpsa` | Show all containers |
| `clean-containers` | Remove stopped containers |
| `clean-images` | Remove dangling images |
| `clean-all` | Remove containers + images |
| `lz` | Open lazydocker |

### Docker Compose

| Command | Description |
|---------|-------------|
| `dcup` | `docker compose up` |
| `dcupd` | `docker compose up -d` |
| `dcdown` | `docker compose down` |
| `dcstop` / `dcstart` | Stop / start services |
| `dclogsf` | Logs with follow |
| `dcexec <svc>` | Exec into service |
| `dcps` | Show containers |

### CDC (Change Directory Context)

Bookmark and jump to project directories.

| Command | Description |
|---------|-------------|
| `cdc add <name> <path>` | Bookmark a project |
| `cdc <name>` | Jump to project |
| `cdc rm <name>` | Remove bookmark |
| `cdc` | List all |

### Notepad

Project-local notes at `./notes.md`.

| Command | Description |
|---------|-------------|
| `note task <text>` | Add task |
| `note ctx <text>` | Add context |
| `note bug <text>` | Add bug |
| `note idea <text>` | Add idea |
| `note code <text>` | Add code snippet |
| `notes` | View all |
| `note wip` | Show incomplete tasks |

### System

| Command | Description |
|---------|-------------|
| `ll` / `la` / `l` | Better ls variants |
| `psg <name>` | Grep processes |
| `..` / `...` | Quick navigation |
| `myip` | Show IP address |
| `copy` / `paste` | Clipboard (mac/linux) |

### FZF Keybindings

| Key | Description |
|-----|-------------|
| `Ctrl+R` | Search shell history |
| `Ctrl+F` | Search files |
| `Alt+C` | Fuzzy change directory |

### General

| Command | Description |
|---------|-------------|
| `kill-port <port>` | Kill process on port |
| `gopen <url>` | Open in browser |
| `tre` | Tree view |
| `...` | Correct last command |

---

## Requirements

| Tool | Required |
|------|---------|
| git | Yes |
| zsh, bash, fish, or dash | Yes |
| fzf | Optional |
| docker | Optional |
| lazydocker | Optional |

## Autoenv

Automatically loads `.env` files when you `cd` into a directory:

```bash
# .env in project root
DATABASE_URL=postgres://localhost:5432
API_KEY=secret

cd ~/project  # .env auto-loaded
echo $DATABASE_URL  # postgres://localhost:5432
```

---

## CLI

Use `omb` (short for oh-my-bd) or `oh-my-bd`:

```bash
omb list              # List plugins
omb list git         # Show git plugin help
omb update           # Pull latest changes
omb help            # Show help
```

| Command | Description |
|---------|-------------|
| `omb install` | Run installer |
| `omb update` | Pull latest changes |
| `omb uninstall` | Remove oh-my-bd |

---

## Help

Each command has built-in help:

```bash
cdc help
note help
context help
dcl help
sys help
```

---

## Uninstall

```bash
oh-my-bd uninstall
```

---

## Contributing

Contributions welcome! Please open an issue or pull request.

---

## Credits

Inspired by [oh-my-zsh](https://github.com/ohmyzsh/ohmyzsh).

Built with these tools:

| Tool | Repo |
|------|------|
| [fzf](https://github.com/junegunn/fzf) | Fuzzy finder |
| [fd](https://github.com/sharkdp/fd) | Fast file finder |
| [thefuck](https://github.com/nvbn/thefuck) | Command correction |
| [lazydocker](https://github.com/jesseduffield/lazydocker) | Docker TUI |

---

## License

MIT

---

[version-badge]: https://img.shields.io/github/v/release/brxndxndiaz/oh-my-bd?label=version
[version-link]: https://github.com/brxndxndiaz/oh-my-bd/releases/latest
[ci-badge]: https://github.com/brxndxndiaz/oh-my-bd/workflows/Test%20Plugins/badge.svg
[ci-link]: https://github.com/brxndxndiaz/oh-my-bd/actions?query=workflow%3ATest%20Plugins
[license-badge]: https://img.shields.io/github/license/brxndxndiaz/oh-my-bd
[license-link]: https://github.com/brxndxndiaz/oh-my-bd/blob/main/LICENSE
