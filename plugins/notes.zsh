# ============================================================
# oh-my-bd — notes.zsh — Project notepad for humans + AI agents
# Notes live in ./notes.md (override: OMBD_NOTES_FILE=NOTES.md).
# Entries look like:  - [12] [2026-11-09 10:00] text
# Finished tasks:     - [x] [12] [2026-11-09 10:00] text
# ============================================================

typeset -gA _OMBD_NOTE_SECTIONS=(
  task Tasks  ctx Context  bug Bugs  idea Ideas  dec Decisions  code Code
)

function _omb_note_file {
  # Prefer the git root so `note` works from any subdirectory of a project.
  local root
  root="$(git rev-parse --show-toplevel 2>/dev/null)" || root="$PWD"
  print -r -- "$root/${OMBD_NOTES_FILE:-notes.md}"
}

function _omb_note_init {
  local f="$(_omb_note_file)"
  [[ -s "$f" ]] && return
  print -rl -- "# Notes" "" "## Tasks" "" "## Context" "" "## Bugs" "" "## Ideas" "" \
    "## Decisions" "" "## Code" "" > "$f"
}

function _omb_note_next_id {
  local max
  max="$(grep -oE '^- (\[x\] )?\[[0-9]+\]' "$(_omb_note_file)" 2>/dev/null |
    grep -oE '[0-9]+' | sort -n | tail -1)"
  print $(( ${max:-0} + 1 ))
}

function _omb_note_add {
  local section="$1"; shift
  local f="$(_omb_note_file)"
  _omb_note_init
  local id="$(_omb_note_next_id)"
  local entry="- [$id] [$(date '+%Y-%m-%d %H:%M')] $*"
  if grep -qx "## $section" "$f"; then
    # Insert after the last entry of the section (keeps chronological order).
    awk -v sec="## $section" -v entry="$entry" '
      $0 == sec { insec = 1; print; next }
      insec && /^## / { print entry; print ""; insec = 0; done = 1; blank = 0 }
      insec && /^[[:space:]]*$/ { blank++; next }
      { while (blank > 0) { print ""; blank-- } print }
      END { if (insec && !done) print entry }
    ' "$f" > "$f.tmp.$$" && command mv -f "$f.tmp.$$" "$f"
  else
    print -r -- $'\n'"## $section"$'\n'"$entry" >> "$f"
  fi
  print "${OMBD_C_DIM}#$id → $section${OMBD_C_RESET}"
}

function _omb_note_pick_id {
  local f="$(_omb_note_file)" line
  line="$(grep -E "${1:-^- \[[0-9]+\]}" "$f" 2>/dev/null | ombd_pick "${2:-Note:}")" || return 1
  print -r -- "${${line#- }#\[x\] }" | grep -oE '^\[[0-9]+\]' | tr -d '[]'
}

function note {
  local f="$(_omb_note_file)"
  case "${1:-}" in
    help|-h)
      cat <<'EOF'
note — Project-local notes (./notes.md at the git root)

  note                Open notes in $EDITOR
  note task <text>    Add to Tasks          note ctx <text>   Add to Context
  note bug <text>     Add to Bugs           note idea <text>  Add to Ideas
  note dec <text>     Add to Decisions      note code <text>  Add to Code
  note <text>         Append a free line
  note done [id]      Mark a task done (picker if no id)
  note wip            Open tasks
  note rm [id]        Remove an entry (picker if no id)
  note clear          Reset notes (asks first)
  notes               Browse/search all notes
EOF
      ;;
    "") _omb_note_init; ${=EDITOR:-vi} "$f" ;;
    open|edit) _omb_note_init; ${=EDITOR:-vi} "$f" ;;
    ls|list) notes ;;
    task|ctx|bug|idea|dec|code)
      local sec="${_OMBD_NOTE_SECTIONS[$1]}"; shift
      (( $# )) || { print "Usage: note ${(k)_OMBD_NOTE_SECTIONS[(r)$sec]} <text>"; return 1; }
      _omb_note_add "$sec" "$*" ;;
    done)
      local id="$2"
      if [[ -z "$id" ]]; then
        local pick; pick="$(note wip | ombd_pick 'Done:')" || return 0
        id="${${pick#- \[}%%\]*}"
      fi
      grep -q "^- \[$id\] " "$f" 2>/dev/null || { print "No open entry #$id"; return 1; }
      sed "s/^- \[$id\] /- [x] [$id] /" "$f" > "$f.tmp.$$" && command mv -f "$f.tmp.$$" "$f"
      print "✓ #$id" ;;
    undone|reopen)
      [[ -z "$2" ]] && { print "Usage: note reopen <id>"; return 1; }
      sed "s/^- \[x\] \[$2\] /- [$2] /" "$f" > "$f.tmp.$$" && command mv -f "$f.tmp.$$" "$f" ;;
    rm)
      local id="$2"
      [[ -z "$id" ]] && { id="$(_omb_note_pick_id '^- (\[x\] )?\[[0-9]+\]' 'Remove:')" || return 0; }
      grep -qE "^- (\[x\] )?\[$id\] " "$f" 2>/dev/null || { print "No entry #$id"; return 1; }
      grep -vE "^- (\[x\] )?\[$id\] " "$f" > "$f.tmp.$$" && command mv -f "$f.tmp.$$" "$f"
      print "Removed #$id" ;;
    wip|todo)
      [[ -f "$f" ]] || { print "No notes here."; return 0; }
      awk '/^## /{ s = ($0 == "## Tasks") } s && /^- \[[0-9]+\]/' "$f" ;;
    clear)
      [[ -f "$f" ]] || return 0
      ombd_confirm "Erase all notes in ${f/#$HOME/~}?" || return 1
      : > "$f"; _omb_note_init; print "Notes cleared." ;;
    *) _omb_note_init; print -r -- "$*" >> "$f" ;;
  esac
}

function notes {
  local f="$(_omb_note_file)"
  [[ "$1" == help ]] && { note help; return; }
  [[ -f "$f" ]] || { print "No notes here. Start with: note task <text>"; return 0; }
  if ombd_use_fzf; then
    grep -E '^- ' "$f" | fzf --height=70% --layout=reverse --border --prompt='Notes: ' \
      --header='Enter: print  •  Esc: close' || true
  else
    cat -- "$f"
  fi
}

noteopen()  { note open; }
function noteclear { note clear; }
alias notepad=notes
