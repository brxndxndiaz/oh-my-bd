# ============================================================
# oh-my-bd — core.zsh — Framework loading and plugin management
# Source this from ~/.zshrc. Everything runs inside an anonymous
# function so no helper variables leak into your shell.
# ============================================================

export OMBD_DIR="${OMBD_DIR:-$HOME/.oh-my-bd}"
export OMBD_CONFIG_DIR="${OMBD_CONFIG_DIR:-${XDG_CONFIG_HOME:-$HOME/.config}/oh-my-bd}"
export OMBD_CUSTOM="${OMBD_CUSTOM:-$OMBD_CONFIG_DIR/plugins}"
export OMBD_VERSION="$(<"$OMBD_DIR/VERSION" 2>/dev/null)"
: "${OMBD_SILENT:=1}"

() {
  emulate -L zsh
  if [[ ! -d "$OMBD_DIR" ]]; then
    print -ru2 -- "[oh-my-bd] OMBD_DIR not found at $OMBD_DIR — run the installer again."
    return 1
  fi

  source "$OMBD_DIR/lib/utils.zsh"

  # User config: ~/.config/oh-my-bd/config.zsh (see config.example.zsh)
  [[ -r "$OMBD_CONFIG_DIR/config.zsh" ]] && source "$OMBD_CONFIG_DIR/config.zsh"

  # Built-in plugins, in load order. Override with OMBD_PLUGINS=(...) in config.
  local -a builtin=(system git docker compose qol notes fzf autoenv)
  (( ${+OMBD_PLUGINS} )) && builtin=("${OMBD_PLUGINS[@]}")
  local -a disabled=("${OMBD_DISABLED_PLUGINS[@]}")

  local p f
  for p in "${builtin[@]}"; do
    (( ${disabled[(Ie)$p]} )) && { ombd_log debug "skip (disabled): $p"; continue; }
    f="$OMBD_DIR/plugins/$p.zsh"
    if [[ -r "$f" ]]; then
      ombd_log debug "load: $p"
      source "$f"
    else
      ombd_log warn "Plugin not found: $p"
    fi
  done

  # Custom plugins (created with `omb add <name>`), loaded alphabetically.
  for f in "$OMBD_CUSTOM"/*.zsh(N); do
    p="${f:t:r}"
    (( ${disabled[(Ie)$p]} )) && continue
    ombd_log debug "load custom: $p"
    source "$f"
  done

  # Completions are only useful in interactive shells.
  [[ -o interactive ]] && source "$OMBD_DIR/lib/completions.zsh"
}

# `omb` as a shell function: with no arguments it opens the command palette,
# otherwise it forwards to the CLI. Defined after plugins so it wins over aliases.
unalias omb 2>/dev/null
omb() {
  if (( $# == 0 )) || [[ "$1" == palette || "$1" == p ]]; then
    ombd_palette
  else
    command "$OMBD_DIR/bin/oh-my-bd" "$@"
  fi
}

# Fuzzy command palette: pick any oh-my-bd command, it lands on your prompt
# ready to edit/run. Also bound to Ctrl+X Ctrl+O (Ctrl+X then Ctrl+O).
ombd_palette() {
  local reg="$OMBD_DIR/lib/commands.tsv" line
  if ! ombd_use_fzf; then
    command "$OMBD_DIR/bin/oh-my-bd" help
    return
  fi
  line="$(grep -v '^#' "$reg" | awk -F'\t' 'NF>=3 { printf "%-8s\t%-26s\t%s\n", $1, $2, $3 }' |
    fzf --height=70% --layout=reverse --border --prompt='omb › ' --delimiter='\t' \
        --header='Enter: put on prompt   Esc: cancel')" || return 0
  setopt localoptions extendedglob
  local cmd="${${(ps:\t:)line}[2]}"
  cmd="${cmd%%<*}"; cmd="${cmd%%\[*}"     # drop <arg> / [opt] placeholders
  cmd="${cmd%%[[:space:]]##}"
  if zle 2>/dev/null; then
    LBUFFER="$cmd "; RBUFFER=""
  else
    print -z -- "$cmd "
  fi
}

if [[ -o interactive ]]; then
  _ombd_palette_widget() { ombd_palette </dev/tty; zle reset-prompt; }
  zle -N _ombd_palette_widget
  bindkey '^X^O' _ombd_palette_widget
fi

# ============================================================
# Update check — at most once per 24h, in the background so it
# never slows down shell startup. The result shows on the next start.
# ============================================================
() {
  emulate -L zsh
  [[ -o interactive ]] || return 0
  [[ -d "$OMBD_DIR/.git" && "${OMBD_SKIP_CHECK:-0}" != "1" ]] || return 0

  local state="$OMBD_CONFIG_DIR/update-check"
  local now=$EPOCHSECONDS
  [[ -z "$now" ]] && { zmodload zsh/datetime 2>/dev/null; now=$EPOCHSECONDS; }
  local last=0 avail=0
  [[ -r "$state" ]] && read -r last avail < "$state"

  if [[ "$avail" == 1 ]]; then
    print -r -- "[oh-my-bd] $(ombd_color yellow 'Update available.') Run $(ombd_color bold 'omb update')."
  fi

  (( now - ${last:-0} < 86400 )) && return 0
  mkdir -p "$OMBD_CONFIG_DIR"
  print -r -- "$now ${avail:-0}" > "$state"      # mark as checked even if offline
  {
    local branch
    branch="$(git -C "$OMBD_DIR" rev-parse --abbrev-ref HEAD 2>/dev/null)"
    [[ -z "$branch" || "$branch" == HEAD ]] && branch=main
    if GIT_TERMINAL_PROMPT=0 git -C "$OMBD_DIR" fetch --quiet origin "$branch" 2>/dev/null; then
      local a=0
      [[ "$(git -C "$OMBD_DIR" rev-parse HEAD)" != "$(git -C "$OMBD_DIR" rev-parse FETCH_HEAD)" ]] &&
        git -C "$OMBD_DIR" merge-base --is-ancestor HEAD FETCH_HEAD 2>/dev/null && a=1
      print -r -- "$now $a" > "$state"
    fi
  } >/dev/null 2>&1 &!
}
