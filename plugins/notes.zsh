# ============================================================
# oh-my-bd — notes.zsh — Project notepad for human + AI
# ============================================================

export OMB_NOTE_ID=0

_omb_note_file() {
  echo "${PWD}/notes.md"
}

_omb_note_init() {
  local notepad="$(_omb_note_file)"
  [[ -f "$notepad" ]] && return
  printf '%s\n' \
    "# Notes" \
    "" \
    "## Tasks" \
    "" \
    "## Context" \
    "" \
    "## Bugs" \
    "" \
    "## Ideas" \
    "" \
    "## Decisions" \
    "" \
    "## Code" \
    > "$notepad"
}

_omb_note_section_line() {
  local notepad="$(_omb_note_file)"
  grep -n "^## ${1}$" "$notepad" 2>/dev/null | cut -d: -f1 | head -1
}

_omb_note_next_id() {
  local notepad="$(_omb_note_file)"
  local max_id
  max_id="$(grep -o '\[ *[0-9]* *\]' "$notepad" 2>/dev/null | grep -o '[0-9]*' | sort -n | tail -1)"
  echo $((max_id + 1))
}

note() {
  local notepad="$(_omb_note_file)"
  _omb_note_init

  if [[ -z "$1" ]] || [[ "$1" == "help" ]]; then
    cat << 'EOF'
note — Project-local notes

Usage:
  note              Open in editor
  note <text>        Append raw text
  note task <text>   Add to Tasks
  note ctx <text>    Add to Context
  note bug <text>    Add to Bugs
  note idea <text>   Add to Ideas
  note dec <text>    Add to Decisions
  note code <text>  Add to Code
  notes             View all notes (or fzf with no args)
  notes ls          View all notes
  note wip          Show incomplete tasks
  note rm <id>      Remove by ID
  note clear        Reset notes

Notes are stored in ./notes.md in the current directory.
EOF
    return
  fi

  case "$1" in
    ls|"")
      notes
      ;;
    task|ctx|bug|idea|dec|code)
      local section
      case "$1" in
        task) section="Tasks" ;;
        ctx)  section="Context" ;;
        bug)  section="Bugs" ;;
        idea) section="Ideas" ;;
        dec)  section="Decisions" ;;
        code) section="Code" ;;
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
        head -n $next_line "$notepad" > "${notepad}.tmp"
        printf '%s\n' "$entry" >> "${notepad}.tmp"
        tail -n +$((next_line + 1)) "$notepad" >> "${notepad}.tmp"
        mv "${notepad}.tmp" "$notepad"
      else
        printf '\n## %s\n%s\n' "$section" "$entry" >> "$notepad"
      fi
      ;;
    ls)
      notes
      ;;
    rm)
      [[ -z "$2" ]] && echo "Usage: note rm <id>" && return 1
      grep -v "^\- \[${2}\] " "$notepad" > "${notepad}.tmp" && mv "${notepad}.tmp" "$notepad"
      ;;
    wip)
      grep "^\- \[" "$notepad" | grep -v "\[x\]" | head -20
      ;;
    clear)
      : > "$notepad"
      _omb_note_init
      ;;
    *)
      printf '%s\n' "$*" >> "$notepad"
      ;;
  esac
}

noteopen() {
  local notepad="$(_omb_note_file)"
  _omb_note_init
  ${EDITOR:-nano} "$notepad"
}

notes() {
  local notepad="$(_omb_note_file)"
  _omb_note_init
  
  if [[ "$1" == "help" ]]; then
    note help
    return
  fi
  
  if [[ -t 1 ]] && command -v fzf >/dev/null 2>&1; then
    local result
    result=$(cat "$notepad" | grep -v '^#' | grep -v '^$' |
      fzf --height=70% --prompt="Notes: " --layout=reverse \
         --bind="enter:execute-silent:echo {} | xargs open 2>/dev/null || echo {}")
    [[ -n "$result" ]] && echo "$result"
  else
    cat "$notepad" || echo "No notes in this directory."
  fi
}

noteclear() {
  local notepad="$(_omb_note_file)"
  : > "$notepad"
  _omb_note_init
  echo "Notes cleared."
}

alias notepad=notes
