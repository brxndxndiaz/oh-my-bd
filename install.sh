#!/usr/bin/env zsh
# ============================================================
# oh-my-bd — install.sh — One-time installer
# ============================================================

set -e

OMBD_DIR="${HOME}/Documents/Github/oh-my-bd"
echo "Installing oh-my-bd to $OMBD_DIR..."

# Backup existing .zshrc
if [[ -f "$HOME/.zshrc" ]]; then
  cp "$HOME/.zshrc" "$HOME/.zshrc.bak.$(date +%Y%m%d%H%M%S)"
  echo "[ok] Backed up existing .zshrc"
fi

# Write minimal .zshrc
cat > "$HOME/.zshrc" << 'EOF'
# ============================================================
# oh-my-bd — managed by oh-my-bd
# Run 'oh-my-bd help' for commands
# ============================================================
export OMBD_DIR="$HOME/Documents/Github/oh-my-bd"
source "$OMBD_DIR/lib/core.zsh"
# ============================================================
# Your custom additions below:
# ============================================================

EOF
echo "[ok] Wrote .zshrc"

# Make CLI executable and symlink
chmod +x "${OMBD_DIR}/bin/oh-my-bd"
mkdir -p "$HOME/.local/bin"
ln -sf "${OMBD_DIR}/bin/oh-my-bd" "$HOME/.local/bin/oh-my-bd"

# Ensure ~/.local/bin is in PATH (add if not)
if [[ ":$PATH:" != *":$HOME/.local/bin:"* ]]; then
  echo 'export PATH="$HOME/.local/bin:$PATH"' >> "$HOME/.zshrc"
fi

echo "[ok] Installed CLI to ~/.local/bin/oh-my-bd"
echo ""
echo "Done! Run: exec zsh"
echo "Then:    oh-my-bd push  (to push to git after making changes)"
