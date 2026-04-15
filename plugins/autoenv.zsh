# ============================================================
# oh-my-bd — autoenv — Auto-load .env on cd
# Supports: zsh, bash, fish, dash, posix
# ============================================================

ombd_autoenv_load() {
  local env_file="${1:-.env}"
  
  if [[ -f "$env_file" ]]; then
    # Export variables from .env (skip comments and empty lines)
    while IFS= read -r line || [[ -n "$line" ]]; do
      # Skip comments and empty lines
      [[ "$line" =~ ^[[:space:]]*# ]] && continue
      [[ -z "${line// }" ]] && continue
      
      # Parse KEY=value
      if [[ "$line" =~ ^([A-Za-z_][A-Za-z0-9_]*)=(.*) ]]; then
        local key="${BASH_REMATCH[1]:-$match[1]}"
        local value
        
        # Extract value - different approach for bash vs zsh
        if [[ -n "$BASH_REMATCH" ]]; then
          value="${BASH_REMATCH[2]}"
        else
          value="${match[2]}"
        fi
        
        # Remove surrounding quotes if present
        value="${value%\"}"
        value="${value#\"}"
        value="${value%\'}"
        value="${value#\'}"
        
        export "$key=$value"
      fi
    done < "$env_file"
  fi
}

# Zsh: use chpwd hook
if [[ -n "$ZSH_VERSION" ]]; then
  ombd_chpwd_hook() {
    ombd_autoenv_load ".env"
  }
  [[ -n "${chpwd_functions[(r)ombd_chpwd_hook]}" ]] || chpwd_functions+=(ombd_chpwd_hook)

# Bash: override cd function
elif [[ -n "$BASH_VERSION" ]]; then
  cd() {
    builtin cd "$@"
    ombd_autoenv_load ".env"
  }

# Fish: use fish_prompt or event handler
elif command -v fish >/dev/null 2>&1; then
  # Fish doesn't source .sh files, this would need a .fish file
  # For now, skip fish autoenv
  :

# Dash/Posix: override cd
else
  cd() {
    # shellcheck disable=SC2164
    builtin cd "$@"
    ombd_autoenv_load ".env"
  }
fi

# Silent - no console output during init
