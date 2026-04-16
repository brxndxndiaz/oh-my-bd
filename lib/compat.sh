# ============================================================
# oh-my-bd — compat.sh — Shell compatibility layer
# Detects shell and provides cross-shell utilities
# ============================================================

# Detect shell
_omb_detect_shell() {
  if [[ -n "$ZSH_VERSION" ]]; then
    echo "zsh"
  elif [[ -n "$BASH_VERSION" ]]; then
    echo "bash"
  elif [[ -n "$FISH_VERSION" ]]; then
    echo "fish"
  elif [[ -n "$POSIXLY_CORRECT" ]] || [[ -z "$BASH_VERSION" && -z "$ZSH_VERSION" ]]; then
    echo "posix"
  else
    echo "unknown"
  fi
}

OMB_SHELL="$(_omb_detect_shell)"

# Cross-shell printf that interprets escapes
omb_printf() {
  printf '%b\n' "$1"
}

# ANSI escape generator (cross-shell compatible)
omb_esc() {
  printf '\033[%sm' "$1"
}

# Color codes using printf (works in all POSIX shells)
OMB_RED="$(printf '\033[0;31m')"
OMB_GREEN="$(printf '\033[0;32m')"
OMB_YELLOW="$(printf '\033[0;33m')"
OMB_BLUE="$(printf '\033[0;34m')"
OMB_CYAN="$(printf '\033[0;36m')"
OMB_BOLD="$(printf '\033[1m')"
OMB_DIM="$(printf '\033[2m')"
OMB_RESET="$(printf '\033[0m')"

# Safe source - works in all shells
omb_source() {
  local file="$1"
  if [[ -f "$file" ]]; then
    source "$file" 2>/dev/null || . "$file"
  fi
}
