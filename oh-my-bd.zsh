# ============================================================
# oh-my-bd — main entry point
# ============================================================
# Source this from your .zshrc:
#   export OMBD_DIR="$HOME/Documents/Github/oh-my-bd"
#   source "$OMBD_DIR/lib/core.zsh"
# ============================================================

if [[ -z "$OMBD_LOADED" ]]; then
  export OMBD_LOADED=1
  source "${OMBD_DIR}/lib/core.zsh"
fi
