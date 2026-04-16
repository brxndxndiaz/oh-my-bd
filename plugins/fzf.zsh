# ============================================================
# oh-my-bd — fzf.zsh — FZF integration
# ============================================================

command -v fzf >/dev/null 2>&1 || return

# Detect shell and source appropriate FZF integration
if [[ -n "$ZSH_VERSION" ]]; then
  eval "$(fzf --zsh)"
elif [[ -n "$BASH_VERSION" ]]; then
  eval "$(fzf --bash)"
fi

# Set up fd as default file finder if available
if command -v fd >/dev/null 2>&1; then
  export FZF_DEFAULT_COMMAND='fd --type f --hidden --follow --exclude .git'
  export FZF_CTRL_T_COMMAND="$FZF_DEFAULT_COMMAND"
  export FZF_ALT_C_COMMAND='fd --type d --hidden --follow --exclude .git'
fi

export FZF_DEFAULT_OPTS='--height 40% --layout=reverse --border --ansi'

# Zsh keybindings (native fzf widgets)
if [[ -n "$ZSH_VERSION" ]]; then
  bindkey '^R' fzf-history-widget
  bindkey '^F' fzf-file-widget
  bindkey '^[c' fzf-cd-widget
fi

# Bash/Fish: use commands directly (fzf, fd, etc.)
# Aliases for non-zsh shells
alias vf='fzf'
alias fcd='cd $(fd --type d --hidden --follow --exclude .git | fzf)'
