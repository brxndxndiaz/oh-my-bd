# ============================================================
# oh-my-bd — fzf.zsh — FZF keybindings and helpers
# ============================================================

ombd_has fzf || return 0

# Key bindings: fzf >= 0.48 ships them via `fzf --zsh`; older versions
# (e.g. Ubuntu/Debian packages) install them as files.
() {
  local ver="${$(fzf --version 2>/dev/null)%% *}" maj min
  maj="${ver%%.*}"; min="${${ver#*.}%%.*}"
  if (( maj > 0 || min >= 48 )); then
    source <(fzf --zsh)
    return
  fi
  local f
  for f in /usr/share/doc/fzf/examples/key-bindings.zsh \
           /usr/share/fzf/key-bindings.zsh \
           /usr/share/fzf/shell/key-bindings.zsh \
           /opt/homebrew/opt/fzf/shell/key-bindings.zsh \
           /usr/local/opt/fzf/shell/key-bindings.zsh \
           "$HOME/.fzf/shell/key-bindings.zsh"; do
    [[ -r "$f" ]] && { source "$f"; return; }
  done
}

if ombd_has fd; then
  export FZF_DEFAULT_COMMAND="${FZF_DEFAULT_COMMAND:-fd --type f --hidden --follow --exclude .git}"
  export FZF_CTRL_T_COMMAND="${FZF_CTRL_T_COMMAND:-$FZF_DEFAULT_COMMAND}"
  export FZF_ALT_C_COMMAND="${FZF_ALT_C_COMMAND:-fd --type d --hidden --follow --exclude .git}"
fi
export FZF_DEFAULT_OPTS="${FZF_DEFAULT_OPTS:---height 40% --layout=reverse --border}"

# Extra binding: Ctrl+F for files (Ctrl+T also works, fzf's default).
(( $+widgets[fzf-file-widget] )) && bindkey '^F' fzf-file-widget

# vf [query] — fuzzy-pick file(s) and open in $EDITOR
function vf {
  local -a files
  local preview='cat {}'
  ombd_has bat && preview='bat --color=always --style=numbers {}'
  files=("${(@f)$(fzf --multi --query="$*" --preview="$preview" --preview-window=right:60%)}")
  files=(${files:#})
  (( ${#files} )) && ${=EDITOR:-vi} -- "${files[@]}"
}

# fcd [query] — fuzzy cd into a subdirectory
function fcd {
  local dir
  if ombd_has fd; then
    dir="$(fd --type d --hidden --follow --exclude .git | fzf --query="$*" --preview='ls -la {}')"
  else
    dir="$(find . -type d -not -path '*/.git*' 2>/dev/null | fzf --query="$*" --preview='ls -la {}')"
  fi
  [[ -n "$dir" ]] && cd -- "$dir"
}

# fh — search history and put the command on the prompt (edit before running)
function fh {
  local cmd
  cmd="$(fc -rln 1 | awk '!seen[$0]++' | fzf --query="$*" --no-sort)" && print -z -- "$cmd"
}
