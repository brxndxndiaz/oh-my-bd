# ============================================================
# oh-my-bd — docker.zsh — Docker context + prompt segment
# ============================================================

# --- CONTEXT helper ---
context() {
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
alias lz='lazydocker'
