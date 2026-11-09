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

# --- Ctrl+F: file finder with switchable scope ----------------
# Tab cycles: here → everywhere (~) → recent (newest first).
# Enter inserts the path(s) at the cursor; Ctrl+O cds to the file's folder.
# Ctrl+Space marks several files. (Ctrl+T is still fzf's plain finder.)
function ombd_find_files {
  local state; state="$(mktemp "${TMPDIR:-/tmp}/ombd-files.XXXXXX")" || return 1
  print -r -- "${1:-here}" > "$state"
  local helper="$OMBD_DIR/bin/ombd-files" out
  out="$(zsh "$helper" list "$state" |
    fzf --height=70% --layout=reverse --border --multi --header-lines=1 \
        --prompt='Files › ' --expect=ctrl-o \
        --bind "tab:reload(zsh ${(q)helper} next ${(q)state})+first" \
        --bind 'ctrl-space:toggle+down' \
        --preview "zsh ${(q)helper} preview {}" --preview-window=right:55%)"
  rm -f -- "$state"
  local -a lines; lines=("${(@f)out}")
  local key="${lines[1]}"; lines=(${lines[2,-1]:#})
  (( ${#lines} )) || return 1
  local -a paths; local p
  for p in "${lines[@]}"; do
    [[ "$p" == "~/"* ]] && p="$HOME/${p#\~/}"
    paths+=("$p")
  done
  # Result: $REPLY is "cd" or "insert", $reply holds the absolute paths.
  reply=("${paths[@]}")
  [[ "$key" == ctrl-o ]] && REPLY=cd || REPLY=insert
}

function _ombd_find_files_widget {
  ombd_find_files </dev/tty || { zle reset-prompt; return 0; }
  if [[ "$REPLY" == cd ]]; then
    cd -- "${reply[1]:h}"
    zle -I; print -r -- "→ ${PWD/#$HOME/~}"
  else
    LBUFFER+="${(j: :)${(q-)reply}} "
  fi
  zle reset-prompt
}
if [[ -o interactive ]]; then
  zle -N _ombd_find_files_widget
  bindkey '^F' _ombd_find_files_widget
fi

# ff [here|everywhere|recent] — same finder as a command: prints the chosen path(s)
function ff {
  ombd_find_files "${1:-here}" || return 0
  if [[ "$REPLY" == cd ]]; then cd -- "${reply[1]:h}"; else print -rl -- "${reply[@]}"; fi
}

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
