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
  # Re-read on live reload too, so `omb config` / `omb enable|disable` apply.
  [[ -r "$OMBD_CONFIG_DIR/config.zsh" ]] && source "$OMBD_CONFIG_DIR/config.zsh"

  # Built-in plugins, in load order. Override with OMBD_PLUGINS=(...) in config.
  local -a builtin=(system git docker compose qol notes fzf autoenv)
  (( ${+OMBD_PLUGINS} )) && builtin=("${OMBD_PLUGINS[@]}")
  local -a disabled=("${OMBD_DISABLED_PLUGINS[@]}")

  # Record every function/alias a plugin defines, so a reload (or a disabled
  # plugin) can remove them cleanly. See ombd_reload.
  typeset -ga _ombd_owned_funcs _ombd_owned_aliases
  _ombd_owned_funcs=() _ombd_owned_aliases=()
  local -a before_f before_a
  _ombd_source_plugin() {
    before_f=(${(k)functions}) before_a=(${(k)aliases})
    source "$1"
    _ombd_owned_funcs+=(${(k)functions:|before_f})
    _ombd_owned_aliases+=(${(k)aliases:|before_a})
  }

  local p f
  for p in "${builtin[@]}"; do
    (( ${disabled[(Ie)$p]} )) && { ombd_log debug "skip (disabled): $p"; continue; }
    f="$OMBD_DIR/plugins/$p.zsh"
    if [[ -r "$f" ]]; then
      ombd_log debug "load: $p"
      _ombd_source_plugin "$f"
    else
      ombd_log warn "Plugin not found: $p"
    fi
  done

  # Custom plugins (created with `omb add <name>`), loaded alphabetically.
  for f in "$OMBD_CUSTOM"/*.zsh(N); do
    p="${f:t:r}"
    (( ${disabled[(Ie)$p]} )) && continue
    ombd_log debug "load custom: $p"
    _ombd_source_plugin "$f"
  done
  unfunction _ombd_source_plugin
  _ombd_owned_funcs=(${_ombd_owned_funcs:#_ombd_source_plugin})

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
    # `omb update`, `omb config`, `omb enable` … signal a reload; this shell
    # and every other open one pick it up before the next prompt.
    command "$OMBD_DIR/bin/oh-my-bd" "$@"
  fi
}

# Fuzzy command palette: pick any oh-my-bd command, it lands on your prompt
# ready to edit/run. Also bound to Ctrl+X Ctrl+O (Ctrl+X then Ctrl+O).
_ombd_palette_rows() {
  local plugin label description name
  while IFS=$'\t' read -r plugin label description; do
    [[ -z "$description" || "$plugin" == \#* ]] && continue
    if [[ "$plugin" != omb ]]; then
      (( ${OMBD_DISABLED_PLUGINS[(Ie)$plugin]:-0} )) && continue
      if (( ${+OMBD_PLUGINS} && ! ${OMBD_PLUGINS[(Ie)$plugin]:-0} )); then
        continue
      fi
      name="${label%% *}"
      (( ${+functions[$name]} || ${+aliases[$name]} )) || continue
    fi
    printf '%-8s\t%-26s\t%s\n' "$plugin" "$label" "$description"
  done < "$OMBD_DIR/lib/commands.tsv"
}

ombd_palette() {
  local line
  if ! ombd_use_fzf; then
    command "$OMBD_DIR/bin/oh-my-bd" help
    return
  fi
  line="$(_ombd_palette_rows |
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
  [[ "${_ombd_reloading:-0}" != 1 ]] && bindkey '^X^O' _ombd_palette_widget
fi

# Wait for the line editor so prompt themes can finish drawing before we print.
function _ombd_daily_tip {
  emulate -L zsh
  [[ -t 1 ]] || return 0
  add-zle-hook-widget -d line-init _ombd_daily_tip
  [[ "${OMBD_TIP_OF_DAY:-1}" != 0 ]] || return 0

  local today state="$OMBD_CONFIG_DIR/tip-of-day" stamp lock last tip
  today="$(command date +%Y%j)" || return 0
  stamp="zle:$today"
  lock="$state.$today.lock"
  [[ -r "$state" ]] && read -r last < "$state"
  [[ "$last" == "$stamp" ]] && return 0

  local -a tips=('Use omb search <term> to look up a command.')
  ombd_use_fzf && tips+=('Use omb to open the command palette.')
  (( ${+functions[cdc]} )) && tips+=('Use cdc add to bookmark the current folder.')
  (( ${+functions[note]} )) && tips+=('Use note task <text> to capture a task in this project.')
  (( ${+functions[work]} )) && tips+=('Use work for a quick overview of your current repo.')
  (( ${+functions[switch]} )) && tips+=('Use switch to pick a Git branch.')
  (( ${+functions[ff]} )) && tips+=('Press Ctrl+F to find a file, then Tab to switch scope.')
  if (( ${+functions[ff]} )); then
    tips+=('Press Ctrl+F twice to search for text inside files.')
  fi
  tip="${tips[10#$today % ${#tips} + 1]}"

  command mkdir -p -- "$OMBD_CONFIG_DIR" 2>/dev/null || return 0
  command mkdir -- "$lock" 2>/dev/null || return 0
  {
    # Another terminal may have already written today's stamp.
    [[ -r "$state" ]] && read -r last < "$state"
    if [[ "$last" != "$stamp" ]]; then
      zle -I 2>/dev/null
      if print -r -- "$(ombd_color cyan 'omb tip ·') $tip"; then
        { print -r -- "$stamp" >| "$state"; } 2>/dev/null
      fi
    fi
  } always {
    command rmdir -- "$lock" 2>/dev/null
  }
  return 0
}

if [[ -o interactive && "${OMBD_TIP_OF_DAY:-1}" != 0 ]]; then
  autoload -Uz add-zsh-hook add-zle-hook-widget
  add-zsh-hook -d precmd _ombd_daily_tip
  add-zle-hook-widget line-init _ombd_daily_tip
fi

# ============================================================
# Live reload — after `omb update`, an automatic update, or a config
# change (`omb config/enable/disable/add/remove`), every open shell
# re-sources oh-my-bd before its next prompt. The check is a single
# builtin `read` of a small marker file, so it costs nothing per prompt.
# ============================================================
typeset -g OMBD_RELOAD_FILE="$OMBD_CONFIG_DIR/reload"
typeset -g _ombd_reload_token=""
[[ -r "$OMBD_RELOAD_FILE" ]] && read -r _ombd_reload_token < "$OMBD_RELOAD_FILE"

ombd_reload() {
  local f h line w old_version="$OMBD_VERSION"
  REPLY=""
  # Never swap in code that doesn't parse: keep the running version instead.
  for f in "$OMBD_DIR"/lib/*.zsh "$OMBD_DIR"/plugins/*.zsh "$OMBD_CUSTOM"/*.zsh(N) "$OMBD_CONFIG_DIR"/config.zsh(N); do
    zsh -n "$f" 2>/dev/null || { print -ru2 -- "[oh-my-bd] not reloading: syntax error in ${f/#$HOME/~}"; return 1; }
  done
  # Remove everything the plugins defined last time, including hooks, widgets
  # and key bindings pointing at them, so disabled/removed commands really go.
  local -a dead_widgets
  for f in "${_ombd_owned_funcs[@]}"; do
    for h in chpwd_functions precmd_functions preexec_functions; do
      (( ${(P)+h} )) && set -A $h ${(P)h:#$f}
    done
    [[ "${widgets[$f]}" == "user:$f" ]] && { zle -D "$f" 2>/dev/null; dead_widgets+=("$f"); }
    unfunction "$f" 2>/dev/null
  done
  if (( ${#dead_widgets} )); then
    for line in "${(@f)$(bindkey -M main 2>/dev/null)}"; do
      w="${line##* }"
      (( ${dead_widgets[(Ie)$w]} )) && bindkey -M main -r "${(Q)${line% *}}"
    done
  fi
  for f in "${_ombd_owned_aliases[@]}"; do unalias "$f" 2>/dev/null; done
  typeset -g _ombd_reloading=1
  source "$OMBD_DIR/lib/core.zsh"
  unset _ombd_reloading
  [[ "$OMBD_VERSION" != "$old_version" ]] && REPLY="$old_version"
  return 0
}

_ombd_reload_check() {
  local token kind
  [[ -r "$OMBD_RELOAD_FILE" ]] && read -r token kind < "$OMBD_RELOAD_FILE"
  [[ "$token" == "${_ombd_reload_token%% *}" ]] && return 0
  _ombd_reload_token="$token"       # handled (even if the reload is refused)
  ombd_reload || return 0
  # Manual `omb …` commands already reported what they did; only announce
  # updates that happened in the background.
  if [[ "$kind" == auto && -n "$REPLY" ]]; then
    print -r -- "[oh-my-bd] $(ombd_color green "updated $REPLY → $OMBD_VERSION") $(ombd_color dim '· omb changelog')"
    local -a missing; missing=(${(f)"$(ombd_missing_tools)"})
    (( ${#missing} )) && print -r -- "[oh-my-bd] $(ombd_color yellow "new features need: ${missing[*]}") — run $(ombd_color bold 'omb deps')"
  fi
}

if [[ -o interactive ]]; then
  autoload -Uz add-zsh-hook
  add-zsh-hook precmd _ombd_reload_check
fi

# ============================================================
# Update check — at most once per 24h, in the background so it never
# slows down shell startup. Fast-forward updates are applied right away
# (OMBD_AUTO_UPDATE=0 to only notify); open shells then live-reload.
# ============================================================
() {
  emulate -L zsh
  [[ -o interactive && "${_ombd_reloading:-0}" != 1 ]] || return 0
  [[ -d "$OMBD_DIR/.git" && "${OMBD_SKIP_CHECK:-0}" != "1" ]] || return 0

  local state="$OMBD_CONFIG_DIR/update-check"
  local now=$EPOCHSECONDS
  [[ -z "$now" ]] && { zmodload zsh/datetime 2>/dev/null; now=$EPOCHSECONDS; }
  local last=0 avail=0
  [[ -r "$state" ]] && read -r last avail < "$state"

  # Only shown when an update couldn't be applied automatically
  # (auto-update off, or local edits in the install dir).
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
      if (( a )) && [[ "${OMBD_AUTO_UPDATE:-1}" != 0 ]] &&
         zsh "$OMBD_DIR/bin/oh-my-bd" update --auto; then
        a=0
      fi
      print -r -- "$now $a" > "$state"
    fi
  } >/dev/null 2>&1 &!
}

return 0
