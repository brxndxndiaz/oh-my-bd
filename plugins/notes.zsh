# ============================================================
# oh-my-bd — notes.zsh — Shared notepad for human + AI
# ============================================================

export NOTEPAD="${HOME}/.notepad.md"
export OMB_NOTE_ID=0

_omb_note_init() {
  [[ -f "$NOTEPAD" ]] && return
  printf '%s\n' \
    "# ============================================================" \
    "# NOTEPAD — shared context between you and your AI agent" \
    "# Sections: TASKS | CONTEXT | BUGS | IDEAS | DECISIONS | CODE" \
    "# Format:   - [id] [timestamp] content" \
    "# ============================================================" \
    "" \
    "## TASKS" \
    "## CONTEXT" \
    "## BUGS" \
    "## IDEAS" \
    "## DECISIONS" \
    "## CODE" \
    > "$NOTEPAD"
}

_omb_note_section_line() {
  local section="$1"
  grep -n "^## ${section}$" "$NOTEPAD" 2>/dev/null | cut -d: -f1 | head -1
}

_omb_note_next_id() {
  local max_id
  max_id="$(grep -o '\[ *[0-9]* *\]' "$NOTEPAD" 2>/dev/null | grep -o '[0-9]*' | sort -n | tail -1)"
  echo $((max_id + 1))
}

note() {
  _omb_note_init

  if [[ -z "$1" ]]; then
    ${EDITOR:-nano} "$NOTEPAD"
    return
  fi

  case "$1" in
    task|ctx|bug|idea|dec|code)
      local section
      case "$1" in
        task) section="TASKS" ;;
        ctx)  section="CONTEXT" ;;
        bug)  section="BUGS" ;;
        idea) section="IDEAS" ;;
        dec)  section="DECISIONS" ;;
        code) section="CODE" ;;
      esac
      shift
      [[ -z "$*" ]] && return

      local id ts entry line
      id="$(_omb_note_next_id)"
      ts="$(date '+%Y-%m-%d %H:%M')"
      entry="- [${id}] [${ts}] $*"
      line="$(_omb_note_section_line "$section")"

      if [[ -n "$line" ]]; then
        local next_line=$((line))
        head -n $next_line "$NOTEPAD" > "${NOTEPAD}.tmp"
        printf '%s\n' "$entry" >> "${NOTEPAD}.tmp"
        tail -n +$((next_line + 1)) "$NOTEPAD" >> "${NOTEPAD}.tmp"
        mv "${NOTEPAD}.tmp" "$NOTEPAD"
      else
        printf '\n## %s\n%s\n' "$section" "$entry" >> "$NOTEPAD"
      fi
      ;;
    ls)
      notes
      ;;
    rm)
      [[ -z "$2" ]] && echo "Usage: note rm <id>" && return 1
      sed -i '' "/^\- \[${2}\] /d" "$NOTEPAD"
      ;;
    wip)
      grep "^\- \[" "$NOTEPAD" | grep -v "\[x\]" | head -20
      ;;
    clear)
      : > "$NOTEPAD"
      _omb_note_init
      ;;
    *)
      printf '%s\n' "$*" >> "$NOTEPAD"
      ;;
  esac
}

noteopen() {
  _omb_note_init
  ${EDITOR:-nano} "$NOTEPAD"
}

notes() {
  _omb_note_init
  [[ -s "$NOTEPAD" ]] && cat "$NOTEPAD" || echo "Notepad is empty."
}

noteclear() {
  : > "$NOTEPAD"
  _omb_note_init
  echo "Notepad cleared."
}
