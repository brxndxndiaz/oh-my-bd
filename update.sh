#!/usr/bin/env zsh
# ============================================================
# oh-my-bd — update.sh — Pull latest from git
# ============================================================

OMBD_DIR="${HOME}/Documents/Github/oh-my-bd"

if [[ ! -d "$OMBD_DIR/.git" ]]; then
  echo "[oh-my-bd] Not a git repo. Run install.sh first."
  exit 1
fi

echo "[oh-my-bd] Pulling latest from git..."
cd "$OMBD_DIR"

# Try master first, then main
git pull --ff-only origin master 2>/dev/null || \
  git pull --ff-only origin main 2>/dev/null || {
    echo "[oh-my-bd] Update failed. You may have local changes."
    echo "  Resolve with: cd $OMBD_DIR && git status"
    exit 1
  }

echo "[oh-my-bd] Up to date."
echo "Run 'exec zsh' to reload."
