# ============================================================
# oh-my-bd — docker.zsh — Docker context + prompt segment
# ============================================================

command -v docker >/dev/null 2>&1 || return

context() {
  if [[ "$1" == "help" ]]; then
    cat << 'EOF'
context — Docker context manager

Usage:
  context             Show current context
  context ls          List all contexts
  context use <name>  Switch to context
EOF
    return
  fi
  command docker context "$@"
}

# --- DOCKER wrapper (safety prompt for non-default context) ---
docker() {
  local current_context
  current_context="$(command docker context show 2>/dev/null)"
  local safe_context="default"

  if [[ "$current_context" != "$safe_context" ]]; then
    echo "WARNING: Docker context is '$current_context' (not 'default')"
    printf "Continue? (y/N): "
    local confirm
    read confirm
    case "$confirm" in
      y|Y) ;;
      *) echo "Aborted."; return 1 ;;
    esac
  fi

  command docker "$@"
}

# --- DOCKER CLEANUP shortcuts ---
alias clean-containers='command docker container prune -f'
alias clean-images='command docker image prune -f'
alias clean-all='command docker system prune -a -f'

# --- DOCKER PS shortcuts ---
alias dps='command docker ps'
alias dpsa='command docker ps -a'

command -v lazydocker >/dev/null 2>&1 && alias lz='lazydocker'
