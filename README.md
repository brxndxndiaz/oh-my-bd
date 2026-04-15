# oh-my-bd

Your personal shell toolkit — wordplay on oh-my-zsh and "oh my bad".

Manages git shortcuts, docker context, shared notepad, and general QoL commands in a version-controlled repo.

## Structure

```
oh-my-bd/
├── bin/oh-my-bd          # CLI entry point
├── lib/
│   ├── core.zsh           # Plugin loader
│   └── utils.zsh          # Utilities
├── plugins/
│   ├── git.zsh            # Git shortcuts
│   ├── docker.zsh         # Docker context + safety wrapper
│   ├── notes.zsh          # Shared notepad (human + AI)
│   ├── qol.zsh            # CDC, kill-port, tre, thefuck, auto-env
│   └── fzf.zsh            # FZF integration
├── install.sh             # First-time installer
├── update.sh              # Pull latest from git
└── README.md
```

## Setup

```bash
# Clone the repo (or create it fresh in ~/Documents/Github/oh-my-bd)
# Then run:
./install.sh
exec zsh
```

## Commands

| Command | Description |
|---|---|
| `oh-my-bd install` | Set up .zshrc, symlink CLI |
| `oh-my-bd update` | Pull latest changes from git |
| `oh-my-bd push [msg]` | Commit and push your changes to git |
| `oh-my-bd add <name>` | Scaffold a new plugin |
| `oh-my-bd remove <name>` | Remove a plugin |
| `oh-my-bd list` | Show installed plugins |

## Shell Shortcuts

### Git
- `status`, `add`, `commit <msg>`, `switch <branch>`, `create <branch>`
- `sync`, `fetch`, `push`, `pull`, `log`
- `undo`, `wipe`, `update`, `rewrite`
- `stash`, `unstash [n]`
- `branches`

### Docker
- `context ls/use/show` — docker context shortcuts
- `clean-containers`, `clean-images`, `clean-all`
- `lz` — lazydocker

### Notepad
- `note task <text>` — add to TASKS
- `note ctx <text>` — add to CONTEXT
- `note bug <text>` — add to BUGS
- `note idea <text>` — add to IDEAS
- `note dec <text>` — add to DECISIONS
- `note code <text>` — add to CODE
- `note <text>` — raw append
- `notes` — view all
- `note wip` — show incomplete tasks
- `note rm <id>` — remove entry
- `noteopen` — open in $EDITOR
- `note clear` — reset

### QoL
- `cdc add <name> <path>` — bookmark a project directory
- `cdc <name>` — jump to bookmarked project
- `cdc rm <name>` — remove bookmark
- `cdc` — list all bookmarks
- `kill-port <port>` — kill process on a port
- `gopen <url>` — open in browser
- `tre` — tree view with common exclusions
- `...` — correct last command (thefuck)

## Workflow

1. Make changes to plugins or add new ones
2. Run `oh-my-bd push "your change description"`
3. On any other machine: `oh-my-bd update && exec zsh`

## Adding a New Plugin

```bash
oh-my-bd add myplugin
# Edit: plugins/myplugin.zsh
oh-my-bd push "add myplugin"
```

## Requirements

- zsh
- git
- fzf (optional, for fuzzy integration)
- thefuck (optional, for command correction)
- lazydocker (optional)
