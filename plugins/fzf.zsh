# ============================================================
# oh-my-bd — fzf.zsh — FZF integration
# ============================================================

if (( $+commands[fzf] )); then
  eval "$(fzf --zsh)"
  export FZF_DEFAULT_COMMAND='fd --type f --hidden --follow --exclude .git'
  export FZF_CTRL_T_COMMAND="$FZF_DEFAULT_COMMAND"
  export FZF_ALT_C_COMMAND='fd --type d --hidden --follow --exclude .git'
  export FZF_DEFAULT_OPTS='--height 40% --layout=reverse --border --ansi'

  bindkey '^R' fzf-history-widget
  bindkey '^F' fzf-file-widget
  bindkey '^[c' fzf-cd-widget
fi
