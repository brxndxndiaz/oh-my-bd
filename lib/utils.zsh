# ============================================================
# oh-my-bd — utils.zsh — General utilities
# ============================================================

# Colored output helpers
_ombd_color() {
  local color="$1"
  shift
  case "$color" in
    red)    echo "\033[0;31m$*\033[0m" ;;
    green)  echo "\033[0;32m$*\033[0m" ;;
    yellow) echo "\033[0;33m$*\033[0m" ;;
    blue)   echo "\033[0;34m$*\033[0m" ;;
    bold)   echo "\033[1m$*\033[0m" ;;
    *)      echo "$*" ;;
  esac
}

ombd_log() {
  local level="$1"
  shift
  local msg="$*"
  case "$level" in
    error)   echo "[oh-my-bd] $(_ombd_color red ERROR) $msg" >&2 ;;
    warn)    echo "[oh-my-bd] $(_ombd_color yellow WARN)  $msg" >&2 ;;
    info)    echo "[oh-my-bd] $(_ombd_color green INFO)  $msg" ;;
    debug)   [[ "${OMBD_DEBUG:-0}" == "1" ]] && echo "[oh-my-bd] DEBUG $msg" ;;
  esac
}

ombd_require() {
  local cmd="$1"
  if ! command -v "$cmd" &>/dev/null; then
    ombd_log "error" "Required command not found: $cmd"
    return 1
  fi
}
