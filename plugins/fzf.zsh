# ============================================================
# oh-my-bd — fzf.zsh — FZF keybindings and helpers
# ============================================================

ombd_has fzf || return 0

# Key bindings: fzf >= 0.48 ships them via `fzf --zsh`; older versions
# (e.g. Ubuntu/Debian packages) install them as files.
() {
  [[ "${_ombd_reloading:-0}" == 1 ]] && return 0
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
# Ctrl+Space selects several files for Enter. (Ctrl+T is still fzf's plain finder.)
function ombd_find_files {
  local state; state="$(mktemp "${TMPDIR:-/tmp}/ombd-files.XXXXXX")" || return 1
  print -r -- "${1:-here}" > "$state"
  local helper="$OMBD_DIR/bin/ombd-files" out status_code
  local toggle='' enter='print'
  if [[ "$2" == widget ]]; then
    enter='insert'
    toggle=',ctrl-f'          # Text mode uses ripgrep, or grep without it
  fi
  out="$(zsh "$helper" list "$state" |
    fzf --height=70% --layout=reverse --border --multi --header-lines=1 \
        --prompt='Files › ' --print-query --query="${3:-}" --expect="ctrl-o$toggle" \
        --header="Enter: $enter · Ctrl+O: go to folder${toggle:+ · Ctrl+F: text}" \
        --bind "tab:reload(zsh ${(q)helper} next ${(q)state})+first" \
        --bind 'ctrl-space:toggle+down' \
        --preview "zsh ${(q)helper} preview {}" --preview-window="right,50%,<50(down,45%)")"
  status_code=$?
  file_scope="$(<"$state")"
  rm -f -- "$state"
  # fzf can return 1 with an expected key when the list has no matches.
  (( status_code <= 1 )) || return 1
  local -a lines; lines=("${(@f)out}")
  local key="${lines[2]}"
  picker_query="${lines[1]}"
  if [[ "$key" == ctrl-f ]]; then
    REPLY=text
    return 0
  fi
  lines=(${lines[3,-1]:#})
  (( ${#lines} )) || return 1
  local -a paths; local p
  for p in "${lines[@]}"; do
    [[ "$p" == "~/"* ]] && p="$HOME/${p#\~/}"
    paths+=("$p")
  done
  reply=("${paths[@]}")
  [[ "$key" == ctrl-o ]] && REPLY=cd || REPLY=insert
}

function _ombd_find_text {
  local helper="$OMBD_DIR/bin/ombd-files" root="$1" project="$2" out key encoded status_code
  local -a rows
  while true; do
    local scope='' tab=''
    if [[ -n "$project" && "$project" != "$PWD" ]]; then
      tab=',tab'
      if [[ "$root" == "$project" ]]; then scope='Tab → this folder only'; else scope='Tab → whole repo'; fi
    fi
    out="$(zsh "$helper" text "$root" "$picker_query" </dev/null |
      fzf --height=70% --layout=reverse --border --no-multi --disabled \
          --prompt='Text › ' --print-query --query="$picker_query" --expect="ctrl-f,ctrl-o$tab" \
          --header="Enter: open · Ctrl+O: go to folder · Ctrl+F: files"$'\n'"In ${root/#$HOME/~}${scope:+   ·   $scope}" \
          --delimiter=$'\t' --with-nth=3.. \
          --bind "change:reload:zsh ${(qq)helper} text ${(qq)root} {q} </dev/null" \
          --preview "zsh ${(qq)helper} text-preview {1} {2}" --preview-window="right,50%,<50(down,45%)")"
    status_code=$?
    (( status_code <= 1 )) || return 1
    rows=("${(@f)out}")
    picker_query="${rows[1]}"
    key="${rows[2]}"
    case "$key" in
      ctrl-f) REPLY=files; return 0 ;;
      tab)
        if [[ "$root" == "$project" ]]; then root="$PWD"; else root="$project"; fi
        continue ;;
    esac
    [[ -n "${rows[3]}" ]] || return 1
    IFS=$'\t' read -r encoded match_line _ <<< "${rows[3]}"
    [[ "$match_line" == <-> ]] || return 1
    reply=("${(Q)encoded}")
    [[ "$key" == ctrl-o ]] && REPLY=cd || REPLY=edit
    return 0
  done
}

function _ombd_find_files_widget {
  local picker_query='' file_scope=here match_line project
  local REPLY mode=files
  local -a reply
  while true; do
    if [[ "$mode" == files ]]; then
      ombd_find_files "$file_scope" widget "$picker_query" </dev/tty || break
    else
      project="$(git rev-parse --show-toplevel 2>/dev/null)"
      _ombd_find_text "$PWD" "$project" </dev/tty || break
    fi
    case "$REPLY" in
      files|text) mode="$REPLY"; continue ;;
      cd)
        # Run a real `cd` from the command line (like fzf's Alt+C) so the prompt
        # redraws for the new folder, chpwd hooks run and it lands in history.
        # Anything already typed comes back after it runs.
        [[ -n "$BUFFER" ]] && zle push-line
        BUFFER="cd -- ${(q-)reply[1]:h}"
        zle accept-line
        return ;;
      edit)
        zle -I
        local -a editor=(${(z)${VISUAL:-${EDITOR:-vi}}})
        editor=("${(@Q)editor}")
        case "${editor[1]:t}" in
          code|code-insiders|codium) "${editor[@]}" --goto "${reply[1]}:$match_line" ;;
          *) "${editor[@]}" "+$match_line" -- "${reply[1]}" ;;
        esac ;;
      insert) LBUFFER+="${(j: :)${(q-)reply}} " ;;
    esac
    break
  done
  zle reset-prompt
}
if [[ -o interactive ]]; then
  zle -N _ombd_find_files_widget
  [[ "${_ombd_reloading:-0}" != 1 ]] && bindkey '^F' _ombd_find_files_widget
fi

# ff [here|everywhere|recent] — same finder as a command: prints the chosen path(s)
function ff {
  local file_scope picker_query REPLY
  local -a reply
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
