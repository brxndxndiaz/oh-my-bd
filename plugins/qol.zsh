# ============================================================
# oh-my-bd — qol.zsh — Quality of life shortcuts
# ============================================================

# --- CDC (project directory bookmark/jump) ---
export CDC_DIR="${HOME}/.cdc_dirs"

cdc() {
  if [[ -z "$1" ]]; then
    if [[ -f "$CDC_DIR" ]]; then
      echo "Available projects:"
      while IFS='|' read -r name path; do
        printf "  %-20s %s\n" "$name" "$path"
      done < "$CDC_DIR"
      echo ""
      echo "Usage: cdc <name>"
    else
      echo "No bookmarks. Add one: cdc add <name> <path>"
    fi
    return
  fi

  case "$1" in
    add)
      [[ -z "$2" || -z "$3" ]] && echo "Usage: cdc add <name> <path>" && return 1
      echo "${2}|${3}" >> "$CDC_DIR"
      echo "Added: $2 -> $3"
      ;;
    rm)
      [[ -z "$2" ]] && echo "Usage: cdc rm <name>" && return 1
      sed -i '' "/^${2}|/d" "$CDC_DIR"
      echo "Removed: $2"
      ;;
    *)
      local target
      target="$(grep "^${1}|" "$CDC_DIR" | head -1 | cut -d'|' -f2)"
      if [[ -n "$target" && -d "$target" ]]; then
        cd "$target" || return
      else
        echo "Unknown project: $1"
        echo "Run 'cdc' to see available projects."
        return 1
      fi
      ;;
  esac
}

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
  open "$1"
}

# --- TRE (tree) ---
alias tre='tree -a --dirsfirst -I ".git|node_modules|vendor|__pycache__|.venv|build|dist"'

# --- THEFUCK ---
if (( $+commands[fuck] )); then
  eval "$(thefuck --alias ...)"
fi

# --- AUTO-SOURCE .env ON CD ---
_auto_env_chpwd() {
  [[ -f .env ]] && set -a && source .env && set +a
fi

autoload -Uz add-zsh-hook
add-zsh-hook chpwd _auto_env_chpwd
_auto_env_chpwd
