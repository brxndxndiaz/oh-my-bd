# ============================================================
# oh-my-bd — qol.zsh — Quality of life shortcuts
# ============================================================

# --- CDC (project directory bookmark/jump) ---
export CDC_DIR="${HOME}/.cdc_dirs"

cdc() {
  if [[ -z "$1" ]] || [[ "$1" == "help" ]]; then
    cat << 'EOF'
cdc — Change Directory Context

Usage:
  cdc <name>          Jump to bookmarked project
  cdc add <name> <path>  Bookmark a directory
  cdc rm <name>       Remove bookmark
  cdc                 List all bookmarks

Examples:
  cdc add myproj ~/Projects/myapp
  cdc myproj
  cdc rm myproj
EOF
    return
  fi

  case "$1" in
    add)
      [[ -z "$2" || -z "$3" ]] && { echo "Usage: cdc add <name> <path>"; return 1; }
      local name="$2" dir="$3"
      dir="${dir:A}"
      local -a kept
      local entry found=0
      for entry in "${(@f)$(cat "$CDC_DIR" 2>/dev/null)}"; do
        [[ -z "$entry" ]] && continue
        local entry_name="${entry%%|*}"
        if [[ "$entry_name" == "$name" ]]; then
          found=1
        else
          kept+=("$entry")
        fi
      done
      if (( found )); then
        echo "Updated: $name -> $dir"
      else
        echo "Added: $name -> $dir"
      fi
      if (( ${#kept[@]} > 0 )); then
        printf '%s\n' "${kept[@]}" > "$CDC_DIR"
      else
        : > "$CDC_DIR"
      fi
      printf '%s\n' "${name}|${dir}" >> "$CDC_DIR"
      ;;
    rm)
      [[ -z "$2" ]] && { echo "Usage: cdc rm <name>"; return 1; }
      local name="$2"
      local -a kept
      local entry found=0
      for entry in "${(@f)$(cat "$CDC_DIR" 2>/dev/null)}"; do
        [[ -z "$entry" ]] && continue
        local entry_name="${entry%%|*}"
        if [[ "$entry_name" == "$name" ]]; then
          found=1
        else
          kept+=("$entry")
        fi
      done
      if (( found )); then
        if (( ${#kept[@]} > 0 )); then
          printf '%s\n' "${kept[@]}" > "$CDC_DIR"
        else
          : > "$CDC_DIR"
        fi
        echo "Removed: $name"
      else
        echo "Unknown bookmark: $name"
      fi
      ;;
    *)
      local line
      line="$(grep "^${1}|" "$CDC_DIR" 2>/dev/null | head -1)"
      local target="${line#*|}"
      if [[ -z "$target" ]]; then
        echo "Unknown project: $1"
        echo "Run 'cdc' to see available projects."
        return 1
      fi
      if [[ ! -d "$target" ]]; then
        echo "Directory does not exist: $target"
        return 1
      fi
      cd "$target"
      ;;
  esac
}

_cdc() {
  local -a names
  names=("${(@f)$(cut -d'|' -f1 "$CDC_DIR" 2>/dev/null)}")

  _arguments \
    '1: :->cmd' \
    '2: :->arg' \
    '3: :->path'

  case "$state" in
    cmd)
      _describe 'bookmark' names
      _describe 'command' '(add rm list)'
      ;;
    arg)
      if [[ "$words[2]" == "add" ]]; then
        _message 'bookmark name'
      elif [[ "$words[2]" == "rm" ]]; then
        _describe 'bookmark' names
      fi
      ;;
    path)
      if [[ "$words[2]" == "add" ]]; then
        _path_files -/
      fi
      ;;
  esac
}

if [[ -o interactive ]]; then
  compdef _cdc cdc 2>/dev/null || true
fi

# --- KILL PORT ---
kill-port() {
  [[ -z "$1" ]] && echo "Usage: kill-port <port>" && return 1
  local pid
  pid="$(lsof -ti :"$1" 2>/dev/null)"
  if [[ -n "$pid" ]]; then
    echo "Killing process $pid on port $1"
    kill -9 "$pid"
  else
    echo "No process found on port $1"
  fi
}

# --- GOPEN (open in browser) ---
gopen() {
  [[ -z "$1" ]] && echo "Usage: gopen <url|file>" && return 1
  if [[ "$(uname)" == "Darwin" ]]; then
    open "$1"
  else
    xdg-open "$1" 2>/dev/null || echo "xdg-open not found"
  fi
}

# --- TRE (tree) ---
command -v tree >/dev/null 2>&1 && alias tre='tree -a --dirsfirst -I ".git|node_modules|vendor|__pycache__|.venv|build|dist"'

# --- THEFUCK ---
if command -v thefuck >/dev/null 2>&1; then
  eval "$(thefuck --alias ...)"
fi

# --- AUTO-SOURCE .env ON CD ---
_auto_env_chpwd() {
  [[ -f .env ]] && set -a && source .env && set +a
}

autoload -Uz add-zsh-hook
add-zsh-hook chpwd _auto_env_chpwd
_auto_env_chpwd
