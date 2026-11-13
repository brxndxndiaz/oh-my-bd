# ============================================================
# oh-my-bd — utils.zsh — Shared helpers used by every plugin
# ============================================================

# --- Colors (only when stdout is a terminal and NO_COLOR is unset) ---
if [[ -t 1 && -z "${NO_COLOR:-}" ]]; then
  typeset -g OMBD_C_RED=$'\e[0;31m' OMBD_C_GREEN=$'\e[0;32m' OMBD_C_YELLOW=$'\e[0;33m'
  typeset -g OMBD_C_BLUE=$'\e[0;34m' OMBD_C_CYAN=$'\e[0;36m' OMBD_C_BOLD=$'\e[1m'
  typeset -g OMBD_C_DIM=$'\e[2m' OMBD_C_RESET=$'\e[0m'
else
  typeset -g OMBD_C_RED= OMBD_C_GREEN= OMBD_C_YELLOW= OMBD_C_BLUE= OMBD_C_CYAN=
  typeset -g OMBD_C_BOLD= OMBD_C_DIM= OMBD_C_RESET=
fi

_ombd_color() {
  local color="$1"; shift
  local c
  case "$color" in
    red) c=$OMBD_C_RED ;; green) c=$OMBD_C_GREEN ;; yellow) c=$OMBD_C_YELLOW ;;
    blue) c=$OMBD_C_BLUE ;; cyan) c=$OMBD_C_CYAN ;; bold) c=$OMBD_C_BOLD ;; dim) c=$OMBD_C_DIM ;;
  esac
  print -r -- "${c}$*${c:+$OMBD_C_RESET}"
}
ombd_color() { _ombd_color "$@"; }

ombd_log() {
  local level="$1"; shift
  [[ "${OMBD_SILENT:-0}" == "1" && "$level" != "error" ]] && return 0
  case "$level" in
    error) print -ru2 -- "[oh-my-bd] $(_ombd_color red ERROR) $*" ;;
    warn)  print -ru2 -- "[oh-my-bd] $(_ombd_color yellow WARN)  $*" ;;
    info)  print -r  -- "[oh-my-bd] $(_ombd_color green INFO)  $*" ;;
    debug) [[ "${OMBD_DEBUG:-0}" == "1" ]] && print -ru2 -- "[oh-my-bd] DEBUG $*" ;;
  esac
  return 0
}

ombd_has() { (( $+commands[$1] )); }

ombd_require() {
  ombd_has "$1" && return 0
  ombd_log error "Required command not found: $1"
  return 1
}

# Interactive helpers need a human at a terminal. Pickers run inside $(...)
# and read their list from a pipe, so stdin/stdout are not terminals there —
# check stderr and that the controlling terminal can be opened.
ombd_interactive() { [[ -t 2 ]] && { : </dev/tty; } 2>/dev/null; }
ombd_use_fzf() { ombd_interactive && ombd_has fzf && [[ "${OMBD_NO_FZF:-0}" != "1" ]]; }

# ombd_confirm "Question?" [default y|n] — returns 0 on yes.
ombd_confirm() {
  local prompt="$1" def="${2:-n}" reply hint="[y/N]"
  [[ "$def" == y ]] && hint="[Y/n]"
  if [[ "${OMBD_ASSUME_YES:-0}" == "1" ]]; then return 0; fi
  if ! [[ -t 0 ]]; then [[ "$def" == y ]]; return; fi
  read -r "reply?${prompt} ${hint} "
  [[ -z "$reply" ]] && reply="$def"
  [[ "$reply" == [yY]* ]]
}

# ombd_pick "Prompt" [fzf args...] — choose one line from stdin.
# Uses fzf when available, falls back to a numbered menu.
ombd_pick() {
  local prompt="$1"; shift
  local -a items
  items=("${(@f)$(cat)}")
  items=(${items:#})
  (( ${#items} )) || return 1
  if ombd_use_fzf; then
    print -rl -- "${items[@]}" | fzf --height=60% --layout=reverse --border \
      --prompt="${prompt} " "$@"
    return
  fi
  ombd_interactive || return 1
  local i=1 item
  for item in "${items[@]}"; do
    printf '  %s%2d%s) %s\n' "$OMBD_C_CYAN" $i "$OMBD_C_RESET" "$item" >/dev/tty
    (( i++ ))
  done
  local choice
  read -r "choice?${prompt} [1-${#items}] " </dev/tty
  [[ "$choice" == <-> ]] && (( choice >= 1 && choice <= ${#items} )) || return 1
  print -r -- "${items[$choice]}"
}

# Open a URL or file with the platform opener.
ombd_open() {
  local target="$1"
  [[ -z "$target" ]] && return 1
  if [[ "$OSTYPE" == darwin* ]]; then
    command open "$target"
  elif ombd_has wslview; then
    wslview "$target"
  elif ombd_has xdg-open; then
    xdg-open "$target" >/dev/null 2>&1 &!
  else
    print -r -- "Open: $target"
    return 1
  fi
}

# Convert any git remote URL (ssh, scp-like, https, with/without .git) to a web URL.
ombd_remote_web_url() {
  local url
  url="$(git remote get-url "${1:-origin}" 2>/dev/null)" || return 1
  [[ -z "$url" ]] && return 1
  url="${url%.git}"
  case "$url" in
    git@*:*)        url="https://${${url#git@}/://}" ;;            # git@host:owner/repo
    ssh://git@*)    url="https://${${url#ssh://git@}/:<->\///}" ;;  # ssh://git@host[:port]/owner/repo
    ssh://*)        url="https://${url#ssh://}" ;;
    git://*)        url="https://${url#git://}" ;;
    https://*@*)    url="https://${url#https://*@}" ;;              # strip credentials
  esac
  print -r -- "$url"
}

# Default branch of a remote (main, master, …).
ombd_default_branch() {
  local remote="${1:-origin}" ref
  ref="$(git symbolic-ref --quiet "refs/remotes/$remote/HEAD" 2>/dev/null)"
  if [[ -n "$ref" ]]; then print -r -- "${ref#refs/remotes/$remote/}"; return; fi
  local b
  for b in main master trunk develop; do
    if git show-ref --verify --quiet "refs/remotes/$remote/$b" || git show-ref --verify --quiet "refs/heads/$b"; then
      print -r -- "$b"; return
    fi
  done
  print -r -- main
}

ombd_in_git() { git rev-parse --is-inside-work-tree >/dev/null 2>&1; }

ombd_sha() {
  if ombd_has sha256sum; then sha256sum -- "$1" | cut -d' ' -f1
  elif ombd_has shasum; then shasum -a 256 -- "$1" | cut -d' ' -f1
  else cksum -- "$1" | cut -d' ' -f1-2 | tr ' ' '-'
  fi
}

# Tools oh-my-bd features rely on: command → what it powers.
# Keep in sync with step 2 of install.sh (`omb deps` installs them).
typeset -gA OMBD_TOOLS=(
  fzf 'pickers and fuzzy search'
  rg  'fast text search (Ctrl+F twice)'
  fd  'fast file search'
  bat 'syntax-highlighted previews'
)

# Print the recommended tools that aren't installed, one per line.
ombd_missing_tools() {
  local t
  for t in fzf rg fd bat; do
    ombd_has "$t" || print -r -- "$t"
  done
}
