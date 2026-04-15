# ============================================================
# oh-my-bd — core.zsh — Framework loading and plugin management
# ============================================================

export OMBD_DIR="${OMBD_DIR:-$HOME/.oh-my-bd}"
export OMBD_VERSION="1.0.0"

# Suppress logs during shell init (avoids p10k warnings)
export OMBD_SILENT="${OMBD_SILENT:-1}"

if [[ ! -d "$OMBD_DIR" ]]; then
  echo "[oh-my-bd] ERROR: OMBD_DIR not found at $OMBD_DIR" >&2
  echo "[oh-my-bd] Run: oh-my-bd install" >&2
  return 1
fi

source "${OMBD_DIR}/lib/utils.zsh"

ombd_log "debug" "oh-my-bd v${OMBD_VERSION} loading from $OMBD_DIR"

# ============================================================
# Load plugins
# ============================================================

local -a plugins=(git docker notes qol fzf compose system autoenv)
for plugin in $plugins; do
  local plugin_file="${OMBD_DIR}/plugins/${plugin}.zsh"
  if [[ -f "$plugin_file" ]]; then
    ombd_log "debug" "Loading plugin: $plugin"
    source "$plugin_file"
  else
    ombd_log "warn" "Plugin not found: $plugin"
  fi
done

# Load completions
local comp_dir="${OMBD_DIR}/plugins/completions"
if [[ -d "$comp_dir" ]]; then
  for f in "${comp_dir}"/*(N.); do
    [[ -f "$f" ]] && source "$f"
  done
fi

ombd_log "debug" "Plugins loaded"

# ============================================================
# Update check — once per 24 hours (oh-my-zsh style)
# ============================================================

ombd_check_update() {
  [[ ! -d "${OMBD_DIR}/.git" ]] && return
  [[ "${OMBD_SKIP_CHECK:-0}" == "1" ]] && return

  local cache_file="${HOME}/.ombd_last_check"
  local interval=86400  # 24 hours in seconds

  # Skip if checked recently
  if [[ -f "$cache_file" ]]; then
    local last_check
    last_check="$(cat "$cache_file" 2>/dev/null)"
    local now
    now="$(date +%s)"
    local age=$((now - last_check))
    (( age < interval )) && return
  fi

  # Fetch remote ref silently
  (cd "$OMBD_DIR" && git fetch origin main --quiet 2>/dev/null) || return

  local local_head remote_head
  local_head="$(cd "$OMBD_DIR" && git rev-parse HEAD 2>/dev/null)"
  remote_head="$(cd "$OMBD_DIR" && git rev-parse origin/main 2>/dev/null)"

  if [[ "$local_head" != "$remote_head" ]]; then
    echo ""
    echo "[oh-my-bd] $(ombd_color yellow Update available.) Run $(ombd_color bold 'oh-my-bd update') to pull."
    echo ""
  fi

  # Update cache
  date +%s > "$cache_file"
}

ombd_check_update
