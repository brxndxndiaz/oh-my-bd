# ============================================================
# oh-my-bd — qol.zsh — Quality of life shortcuts
# ============================================================

# --- CDC: project bookmarks ---------------------------------
# File format: one "name|/absolute/path" per line, most recently used last.
export CDC_DIR="${CDC_DIR:-$HOME/.cdc_dirs}"

function _cdc_lookup {   # exact name match → path
  [[ -f "$CDC_DIR" ]] || return 1
  awk -F'|' -v n="$1" '$1 == n { sub(/^[^|]*\|/, ""); print; exit }' "$CDC_DIR"
}

function _cdc_without {  # all entries except name
  [[ -f "$CDC_DIR" ]] || return 0
  awk -F'|' -v n="$1" 'NF && $1 != n' "$CDC_DIR"
}

function _cdc_write {    # replace file with stdin, atomically
  local tmp="$CDC_DIR.tmp.$$"
  cat > "$tmp" && command mv -f "$tmp" "$CDC_DIR"
}

function _cdc_touch {    # move entry to the end (most recent)
  local name="$1" dir="$2"
  { _cdc_without "$name"; print -r -- "$name|$dir"; } | _cdc_write
}

function _cdc_pick {     # interactive chooser, most recent first → prints name
  [[ -s "$CDC_DIR" ]] || { print "No bookmarks. Add one: cdc add <name> [path]" >&2; return 1; }
  local -a lines; lines=("${(@Oaf)$(<"$CDC_DIR")}")
  local line
  line="$(print -rl -- "${(@)lines:#}" |
    awk -F'|' '{ p = $0; sub(/^[^|]*\|/, "", p); printf "%s\t%s\n", $1, p }' |
    ombd_pick "${1:-Jump to:}" --delimiter='\t' --tabstop=22 \
      --preview='ls -la {2} 2>/dev/null | head -40' --preview-window=right:50%)" || return 1
  print -r -- "${line%%$'\t'*}"
}

function cdc {
  case "${1:-}" in
    help|-h)
      cat <<'EOF'
cdc — Change Directory Context (project bookmarks)

  cdc                    Pick a bookmark (fzf / menu), most recent first
  cdc <name>             Jump to bookmark
  cdc add <name> [path]  Add/update bookmark (path defaults to current dir)
  cdc add                Bookmark current dir under its folder name
  cdc rm [name]          Remove bookmark (picker if no name)
  cdc ls                 List bookmarks
  cdc clean              Remove bookmarks whose directory no longer exists
EOF
      ;;
    "")
      local name; name="$(_cdc_pick)" || return 0
      cdc "$name" ;;
    ls|list)
      [[ -s "$CDC_DIR" ]] || { print "No bookmarks. Add one: cdc add <name> [path]"; return 0; }
      local n d
      while IFS='|' read -r n d; do
        [[ -z "$n" ]] && continue
        if [[ -d "$d" ]]; then printf '  %s%-20s%s %s\n' "$OMBD_C_CYAN" "$n" "$OMBD_C_RESET" "${d/#$HOME/~}"
        else printf '  %s%-20s %s (missing)%s\n' "$OMBD_C_DIM" "$n" "${d/#$HOME/~}" "$OMBD_C_RESET"; fi
      done < "$CDC_DIR" ;;
    add)
      local dir="${3:-$PWD}" name="${2:-${PWD:t}}"
      [[ "$name" == *'|'* ]] && { print "Bookmark names can't contain '|'"; return 1; }
      [[ -d "$dir" ]] || { print "Not a directory: $dir"; return 1; }
      dir="${dir:A}"
      if [[ -n "$(_cdc_lookup "$name")" ]]; then
        print "Updated: $name → ${dir/#$HOME/~}"
      else
        print "Added: $name → ${dir/#$HOME/~}"
      fi
      _cdc_touch "$name" "$dir" ;;
    rm|remove)
      local name="$2"
      [[ -z "$name" ]] && { name="$(_cdc_pick 'Remove:')" || return 0; }
      [[ -z "$(_cdc_lookup "$name")" ]] && { print "Unknown bookmark: $name"; return 1; }
      _cdc_without "$name" | _cdc_write
      print "Removed: $name" ;;
    clean)
      [[ -f "$CDC_DIR" ]] || return 0
      local n d; local -a keep gone
      while IFS='|' read -r n d; do
        [[ -z "$n" ]] && continue
        if [[ -d "$d" ]]; then keep+=("$n|$d"); else gone+=("$n"); fi
      done < "$CDC_DIR"
      (( ${#gone} )) || { print "Nothing to clean."; return 0; }
      print -rl -- "${keep[@]}" | _cdc_write
      print "Removed: ${gone[*]}" ;;
    *)
      local target; target="$(_cdc_lookup "$1")"
      if [[ -z "$target" ]]; then
        print "Unknown project: $1   (cdc ls to list, cdc add $1 to create)"
        return 1
      fi
      [[ -d "$target" ]] || { print "Directory no longer exists: $target  (cdc clean)"; return 1; }
      _cdc_touch "$1" "$target"
      cd "$target" ;;
  esac
}

# --- RECENT --- recently used bookmarks
function recent {
  [[ -s "$CDC_DIR" ]] || { print "No bookmarks yet. Add: cdc add <name> [path]"; return 0; }
  if ombd_interactive; then
    local name; name="$(_cdc_pick 'Recent:')" && cdc "$name"
  else
    local -a lines; lines=("${(@Oaf)$(<"$CDC_DIR")}")
    print -rl -- "${(@)lines[1,10]}" | awk -F'|' '{ print "  " $1 " → " $2 }'
  fi
}

# --- MKCD --- mkdir + cd
function mkcd {
  [[ -z "$1" ]] && { print "Usage: mkcd <dir>"; return 1; }
  mkdir -p -- "$1" && cd -- "$1"
}

# --- KILL PORT --- `kill-port` alone lists listening ports to pick from
function kill-port {
  ombd_require lsof || return 1
  local port="$1"
  if [[ -z "$port" ]]; then
    local line
    line="$(lsof -nP -iTCP -sTCP:LISTEN 2>/dev/null | awk 'NR > 1 { n = split($9, a, ":"); printf "%-6s %-8s %-18s %s\n", a[n], $2, $1, $3 }' |
      sort -un | ombd_pick 'Kill (port pid cmd user):')" || return 0
    port="${line%% *}"
  fi
  [[ "$port" == <-> ]] || { print "Usage: kill-port [port]"; return 1; }
  local -a pids; pids=(${(f)"$(lsof -ti tcp:"$port" -sTCP:LISTEN 2>/dev/null)"})
  (( ${#pids} )) || { print "No process listening on :$port"; return 1; }
  local pid
  for pid in "${pids[@]}"; do
    print "Stopping $(ps -o comm= -p "$pid" 2>/dev/null) (pid $pid) on :$port"
    kill "$pid" 2>/dev/null
  done
  sleep 1
  for pid in "${pids[@]}"; do
    if kill -0 "$pid" 2>/dev/null; then
      ombd_confirm "pid $pid still running. Force kill (-9)?" y && kill -9 "$pid"
    fi
  done
}

# --- GOPEN --- open a URL/file in the default app
function gopen {
  [[ -z "$1" ]] && { print "Usage: gopen <url|file>"; return 1; }
  ombd_open "$1"
}

# --- EXTRACT --- unpack any common archive
function extract {
  [[ -f "$1" ]] || { print "Usage: extract <archive>"; return 1; }
  case "${1:l}" in
    *.tar.gz|*.tgz)   tar -xzf "$1" ;;
    *.tar.bz2|*.tbz2) tar -xjf "$1" ;;
    *.tar.xz|*.txz)   tar -xJf "$1" ;;
    *.tar.zst)        tar --zstd -xf "$1" ;;
    *.tar)            tar -xf "$1" ;;
    *.gz)             gunzip -k "$1" ;;
    *.bz2)            bunzip2 -k "$1" ;;
    *.xz)             unxz -k "$1" ;;
    *.zip|*.jar)      unzip "$1" ;;
    *.7z)             7z x "$1" ;;
    *.rar)            unrar x "$1" ;;
    *) print "Don't know how to extract: $1"; return 1 ;;
  esac
}

# --- SERVE --- static file server for the current directory
function serve {
  local port="${1:-8000}"
  if ombd_has python3; then
    print "Serving $PWD at http://localhost:$port (Ctrl+C to stop)"
    python3 -m http.server "$port"
  elif ombd_has npx; then npx --yes serve -l "$port"
  else print "Needs python3 or npx"; return 1; fi
}

# --- TRE --- tree without the noise
if ombd_has tree; then
  alias tre='tree -a --dirsfirst -I ".git|node_modules|vendor|__pycache__|.venv|build|dist"'
fi

# --- TF --- fix the last command with thefuck
if ombd_has thefuck; then
  function tf {
    setopt localoptions extendedglob
    local cmd fixed
    if (( $# )); then cmd="$*"; else cmd="$(fc -ln -1)"; cmd="${cmd##[[:space:]]#}"; fi
    fixed="$(THEFUCK_REQUIRE_CONFIRMATION=False thefuck -y "$cmd" 2>/dev/null)"
    [[ -z "$fixed" ]] && { print "No correction found."; return 1; }
    print -r -- "→ $fixed"
    print -s -- "$fixed"
    eval "$fixed"
  }
fi
