# ============================================================
# oh-my-bd — autoenv.zsh — Load ./.env when you cd into a directory
#
# Safety:
#   * A .env is only loaded after you approve it. Approval is tied to the
#     file's path AND content hash, so an edited file asks again.
#   * Variables that can hijack your shell or tools (PATH, LD_PRELOAD,
#     GIT_SSH_COMMAND, …) are never set from a .env.
#   * Leaving the directory restores the previous values.
#
# Config (in ~/.config/oh-my-bd/config.zsh):
#   OMBD_AUTOENV=0            disable entirely
#   OMBD_AUTOENV_QUIET=1      don't print which variables were loaded
# Commands:
#   autoenv                   status for the current directory
#   autoenv allow | deny      trust / untrust ./.env
#   autoenv reload            reload ./.env
# ============================================================

[[ "${OMBD_AUTOENV:-1}" == 0 ]] && return 0

typeset -g OMBD_AUTOENV_TRUST="${OMBD_AUTOENV_TRUST:-$OMBD_CONFIG_DIR/autoenv-trusted}"
typeset -g _ombd_autoenv_dir="${_ombd_autoenv_dir:-}"          # directory whose .env is currently loaded
typeset -gA _ombd_autoenv_saved          # key -> previous value
typeset -gA _ombd_autoenv_unexported
typeset -ga _ombd_autoenv_unset          # keys that were unset before loading

typeset -ga OMBD_AUTOENV_BLOCKED=(
  PATH FPATH MANPATH CDPATH HOME PWD OLDPWD SHELL USER LOGNAME IFS PS1 PS2 PS3 PS4 PROMPT RPROMPT
  ZDOTDIR ENV BASH_ENV PROMPT_COMMAND PERL5LIB PERL5OPT PYTHONPATH PYTHONSTARTUP
  RUBYOPT NODE_OPTIONS EDITOR VISUAL PAGER GIT_EDITOR SSH_AUTH_SOCK SUDO_ASKPASS
  OMBD_DIR OMBD_CONFIG_DIR OMBD_CUSTOM OMBD_AUTOENV_TRUST
)
function _ombd_autoenv_blocked {
  local k="$1"
  (( ${OMBD_AUTOENV_BLOCKED[(Ie)$k]} )) && return 0
  [[ "$k" == (LD_*|DYLD_*|GIT_*|ZSH_*|_ombd_autoenv_*) ]]
}

# Parse a .env file and print "KEY<TAB>VALUE" lines.
# Supports: KEY=value, export KEY=value, 'single', "double" (with \n \" \\),
# and trailing " # comments" on unquoted values. Values may contain = and #.
function _ombd_autoenv_parse {
  emulate -L zsh
  setopt extendedglob
  local line key val q
  while IFS= read -r line || [[ -n "$line" ]]; do
    line="${line%$'\r'}"
    line="${line##[[:space:]]#}"
    [[ -z "$line" || "$line" == \#* ]] && continue
    line="${line#export[[:space:]]##}"
    [[ "$line" == (#b)([A-Za-z_][A-Za-z0-9_]#)[[:space:]]#=[[:space:]]#(*) ]] || continue
    key="$match[1]" val="$match[2]"
    q="${val[1]}"
    if [[ "$q" == \" || "$q" == \' ]] && [[ "${val[2,-1]}" == *"$q"* ]]; then
      val="${val[2,-1]}"
      if [[ "$q" == \" ]]; then
        # take up to the first unescaped closing quote, then unescape
        local out="" i=1 c
        while (( i <= ${#val} )); do
          c="${val[i]}"
          if [[ "$c" == \\ ]]; then
            (( i++ )); c="${val[i]}"
            case "$c" in n) out+=$'\n' ;; t) out+=$'\t' ;; *) out+="$c" ;; esac
          elif [[ "$c" == \" ]]; then break
          else out+="$c"; fi
          (( i++ ))
        done
        val="$out"
      else
        val="${val%%\'*}"
      fi
    else
      val="${val%%[[:space:]]##\#*}"          # strip " # comment"
      val="${val%%[[:space:]]#}"
    fi
    print -r -- "$key"$'\t'"${val//$'\n'/\\n}"
  done < "$1"
}

function _ombd_autoenv_trusted {
  local file="${1:A}" sum
  [[ -f "$file" && -r "$OMBD_AUTOENV_TRUST" ]] || return 1
  sum="$(ombd_sha "$file")"
  grep -qxF -- "$sum $file" "$OMBD_AUTOENV_TRUST"
}

function _ombd_autoenv_trust {
  local file="${1:A}"
  mkdir -p "${OMBD_AUTOENV_TRUST:h}"
  _ombd_autoenv_untrust "$file"
  print -r -- "$(ombd_sha "$file") $file" >> "$OMBD_AUTOENV_TRUST"
}

function _ombd_autoenv_untrust {
  local file="${1:A}"
  [[ -f "$OMBD_AUTOENV_TRUST" ]] || return 0
  local tmp="$OMBD_AUTOENV_TRUST.tmp.$$"
  awk -v f="$file" '{ p = $0; sub(/^[^ ]+ /, "", p); if (p != f) print }' "$OMBD_AUTOENV_TRUST" > "$tmp"
  command mv -f "$tmp" "$OMBD_AUTOENV_TRUST"
}

function _ombd_autoenv_unload {
  [[ -z "$_ombd_autoenv_dir" ]] && return 0
  local k
  for k in "${(@k)_ombd_autoenv_saved}"; do
    if (( ${+_ombd_autoenv_unexported[$k]} )); then
      typeset -g +x "$k=${_ombd_autoenv_saved[$k]}"
    else
      export "$k=${_ombd_autoenv_saved[$k]}"
    fi
  done
  for k in "${_ombd_autoenv_unset[@]}"; do
    unset "$k"
  done
  _ombd_autoenv_saved=() _ombd_autoenv_unexported=() _ombd_autoenv_unset=() _ombd_autoenv_dir=""
}

# ombd_autoenv_load [file] — load (after trust check) and remember for unload.
function ombd_autoenv_load {
  local file="${1:-.env}"
  [[ -f "$file" && -r "$file" ]] || return 0
  local _ombd_autoenv_root="${file:h}"
  file="${file:A}"

  if ! _ombd_autoenv_trusted "$file"; then
    [[ -t 0 && -t 2 ]] || return 0     # never auto-trust without a human
    local keys
    keys="$(_ombd_autoenv_parse "$file" | cut -f1 | tr '\n' ' ')"
    print -u2 -- "[oh-my-bd] $(ombd_color yellow 'Untrusted .env') ${file/#$HOME/~}"
    print -u2 -- "           sets: ${keys:-(nothing)}"
    local reply
    read -r "reply?           Load it? [y]es once / [a]lways / [N]o: " </dev/tty
    case "$reply" in
      a|A) _ombd_autoenv_trust "$file" ;;
      y|Y) ;;
      *) return 0 ;;
    esac
  fi

  _ombd_autoenv_unload
  local key val line
  local -a loaded skipped
  while IFS=$'\t' read -r key val; do
    if _ombd_autoenv_blocked "$key"; then skipped+=("$key"); continue; fi
    (( ${loaded[(Ie)$key]} )) && { export "$key=${val//\\n/$'\n'}"; continue; }
    if (( ${+parameters[$key]} )); then
      _ombd_autoenv_saved[$key]="${(P)key}"
      [[ "${parameters[$key]}" != *-export* ]] && _ombd_autoenv_unexported[$key]=1
    else
      _ombd_autoenv_unset+=("$key")
    fi
    export "$key=${val//\\n/$'\n'}"
    loaded+=("$key")
  done < <(_ombd_autoenv_parse "$file")
  _ombd_autoenv_dir="${_ombd_autoenv_root:A}"

  if [[ "${OMBD_AUTOENV_QUIET:-0}" != 1 && -t 2 ]]; then
    (( ${#loaded} )) && print -u2 -- "[oh-my-bd] .env loaded: ${loaded[*]}"
  fi
  (( ${#skipped} )) && print -u2 -- "[oh-my-bd] .env $(ombd_color yellow 'ignored unsafe keys'): ${skipped[*]}"
  return 0
}

function _ombd_autoenv_chpwd {
  local _ombd_autoenv_left='' _ombd_autoenv_root="${PWD:A}"
  if [[ -n "$_ombd_autoenv_dir" && "$_ombd_autoenv_root/" != "$_ombd_autoenv_dir/"* ]]; then
    _ombd_autoenv_unload
    _ombd_autoenv_left=1
  fi
  [[ -f "$_ombd_autoenv_root/.env" && "$_ombd_autoenv_root" != "$_ombd_autoenv_dir" ]] && ombd_autoenv_load "$_ombd_autoenv_root/.env"
  if [[ -n "$_ombd_autoenv_left" && -z "$_ombd_autoenv_dir" ]]; then
    while [[ "$_ombd_autoenv_root" != / ]]; do
      _ombd_autoenv_root="${_ombd_autoenv_root:h}"
      if _ombd_autoenv_trusted "$_ombd_autoenv_root/.env"; then
        ombd_autoenv_load "$_ombd_autoenv_root/.env"
        break
      fi
    done
  fi
  return 0
}

function autoenv {
  local f="$PWD/.env"
  case "${1:-}" in
    allow|trust) [[ -f "$f" ]] || { print "No .env here."; return 1; }
                 _ombd_autoenv_trust "$f"; ombd_autoenv_load "$f" ;;
    deny|untrust) _ombd_autoenv_untrust "$f"; _ombd_autoenv_unload; print "Untrusted ${f/#$HOME/~}" ;;
    reload)      _ombd_autoenv_unload; ombd_autoenv_load "$f" ;;
    unload)      _ombd_autoenv_unload ;;
    help|-h)     sed -n '2,20p' "$OMBD_DIR/plugins/autoenv.zsh" | sed 's/^# \{0,1\}//' ;;
    "")
      if [[ -f "$f" ]]; then
        if _ombd_autoenv_trusted "$f"; then print ".env: trusted"; else print ".env: not trusted (autoenv allow)"; fi
      else print "No .env in this directory."; fi
      [[ -n "$_ombd_autoenv_dir" ]] && print "active: ${_ombd_autoenv_dir/#$HOME/~} (${(j:, :)${(@k)_ombd_autoenv_saved} ${_ombd_autoenv_unset}})"
      ;;
    *) print "Usage: autoenv [allow|deny|reload|unload|help]"; return 1 ;;
  esac
}

autoload -Uz add-zsh-hook
add-zsh-hook chpwd _ombd_autoenv_chpwd
# Handle the directory the shell starts in, but only for interactive shells.
[[ -o interactive && "${_ombd_reloading:-0}" != 1 ]] && _ombd_autoenv_chpwd
