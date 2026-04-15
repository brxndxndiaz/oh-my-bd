#!/usr/bin/env zsh
# vim: set filetype=zsh:

# ============================================================
# oh-my-bd — core.zsh — Framework loading and plugin management
# ============================================================

# Resolve the oh-my-bd directory
export OMBD_DIR="${OMBD_DIR:-$HOME/Documents/Github/oh-my-bd}"
export OMBD_VERSION="0.1.0"

# Ensure directory exists
if [[ ! -d "$OMBD_DIR" ]]; then
  echo "[oh-my-bd] ERROR: OMBD_DIR not found at $OMBD_DIR" >&2
  echo "[oh-my-bd] Run: oh-my-bd install" >&2
  return 1
fi

# Load utilities first
source "${OMBD_DIR}/lib/utils.zsh"

ombd_log "debug" "oh-my-bd v${OMBD_VERSION} loading from $OMBD_DIR"

# Load plugins in order
local -a plugins=(
  git
  docker
  notes
  qol
  fzf
)

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
  for f in "$comp_dir"/*; do
    [[ -f "$f" ]] && source "$f"
  done
fi

ombd_log "info" "oh-my-bd loaded successfully"
