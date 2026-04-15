#!/usr/bin/env zsh
# ============================================================
# oh-my-bd — Installer
# Usage: sh -c "$(curl -fsSL https://raw.githubusercontent.com/brxndxndiaz/oh-my-bd/main/install.sh)"
# ============================================================

set -e

OMBD_DIR="${HOME}/.oh-my-bd"
REPO_URL="https://github.com/brxndxndiaz/oh-my-bd"
BRANCH="main"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
BOLD='\033[1m'
RESET='\033[0m'

print_header() {
  echo ""
  echo -e "${BLUE}       ______     __  __        __    __     __  __        ______     _____${RESET}"
  echo -e "${BLUE}      /\\  __ \\   /\\ \\_\\ \\      /\\ \"-./  \\   /\\ \\_\\ \\      /\\  == \\   /\\  __-. ${RESET}"
  echo -e "${BLUE}      \\ \\  __ \\  \\ \\  __ \\     \\ \\ -.\\/\\ \\  \\ \\____ \\     \\ \\  __<   \\ \\ \\/\\ \\ ${RESET}"
  echo -e "${BLUE}       \\ \\_____\\  \\ \\_\\ \\_\\     \\ \\_\\ \\ \\_\\  \\/\\_\_\_\_\\_\\     \\ \_____\\  \\ \\____- ${RESET}"
  echo -e "${BLUE}        \\/_/___/   \\/_/\\/_/      \\/_/  \\_/_/   \\/_/___/__/      \\/_/___/__/   \\/__/__/ ${RESET}"
  echo ""
}

has_cmd() { command -v "$1" &>/dev/null; }

get_pkg_manager() {
  if has_cmd brew; then echo "brew"
  elif has_cmd apt; then echo "apt"
  elif has_cmd dnf; then echo "dnf"
  elif has_cmd pacman; then echo "pacman"
  elif has_cmd apk; then echo "apk"
  else echo ""
  fi
}

install_pkg() {
  local cmd="$1"
  local name="$2"
  local pkg="$3"
  local manager
  manager="$(get_pkg_manager)"

  if has_cmd "$cmd"; then
    echo -e "  ${GREEN}✓${RESET} $name (already installed)"
    return 0
  fi

  if [[ -z "$manager" ]]; then
    echo -e "  ${YELLOW}−${RESET} $name (no package manager found)"
    return 0
  fi

  echo -n "  Install $name? [y/N] "
  if read -q; then
    echo
    case "$manager" in
      brew)   brew install "$pkg" ;;
      apt)    sudo apt install -y "$pkg" ;;
      dnf)    sudo dnf install -y "$pkg" ;;
      pacman) sudo pacman -S --noconfirm "$pkg" ;;
      apk)    sudo apk add "$pkg" ;;
    esac && echo -e "  ${GREEN}✓${RESET} $name installed" || echo -e "  ${YELLOW}!${RESET} $name failed"
  else
    echo && echo -e "  ${YELLOW}−${RESET} $name skipped"
  fi
}

# ============================================================
# Main
# ============================================================

print_header

echo -e "${BOLD}Installing oh-my-bd...${RESET}"
echo ""

# Required deps
echo -e "${BOLD}[1/4] Checking required dependencies...${RESET}"
if ! has_cmd zsh; then
  echo -e "  ${RED}✗${RESET} zsh is required"
  echo "    Install: https://github.com/ohmyzsh/ohmyzsh/wiki/Installing-ZSH"
  exit 1
fi
echo -e "  ${GREEN}✓${RESET} zsh"

if ! has_cmd git; then
  echo -e "  ${RED}✗${RESET} git is required"
  echo "    Install: https://git-scm.com/book/en/v2/Getting-Started-Installing-Git"
  exit 1
fi
echo -e "  ${GREEN}✓${RESET} git"

# Optional deps
echo ""
echo -e "${BOLD}[2/4] Optional tools?${RESET}"
echo ""
install_pkg fzf "FZF (fuzzy finder)" "fzf"
install_pkg fd "fd (fast file finder)" "fd"
install_pkg thefuck "thefuck (command correction)" "thefuck"
install_pkg lazydocker "lazydocker (Docker TUI)" "lazydocker"
install_pkg tree "tree (directory viewer)" "tree"

# Install oh-my-bd
echo ""
echo -e "${BOLD}[3/4] Installing oh-my-bd...${RESET}"

if [[ -d "$OMBD_DIR/.git" ]]; then
  echo -e "  ${GREEN}✓${RESET} Already installed at $OMBD_DIR"
  echo -e "  ${GREEN}✓${RESET} Pulling latest..."
  (cd "$OMBD_DIR" && git pull --ff-only origin main 2>/dev/null) || true
else
  git clone --branch "$BRANCH" --depth 1 "$REPO_URL" "$OMBD_DIR"
  cd "$OMBD_DIR"
  git remote set-url --push origin NO_PUSH
  echo -e "  ${GREEN}✓${RESET} Cloned from GitHub"
fi

# Configure .zshrc
echo ""
echo -e "${BOLD}[4/4] Configuring .zshrc...${RESET}"

if grep -q "oh-my-bd" "${HOME}/.zshrc" 2>/dev/null; then
  echo -e "  ${YELLOW}−${RESET} Already configured"
else
  cat >> "${HOME}/.zshrc" << 'ZSHRC'

# ============================================================
# oh-my-bd — git shortcuts, docker helpers, notes, CDC & more
# ============================================================
export OMBD_DIR="$HOME/.oh-my-bd"
[[ -f "$OMBD_DIR/lib/core.zsh" ]] && source "$OMBD_DIR/lib/core.zsh"
alias omb="oh-my-bd"
ZSHRC
  echo -e "  ${GREEN}✓${RESET} Added to .zshrc"
fi

# Symlink CLI
mkdir -p "${HOME}/.local/bin"
ln -sf "${OMBD_DIR}/bin/oh-my-bd" "${HOME}/.local/bin/oh-my-bd"
ln -sf "${OMBD_DIR}/bin/oh-my-bd" "${HOME}/.local/bin/omb"
chmod +x "${OMBD_DIR}/bin/oh-my-bd"
echo -e "  ${GREEN}✓${RESET} CLI → ~/.local/bin/oh-my-bd"
echo -e "  ${GREEN}✓${RESET} Alias → ~/.local/bin/omb"

echo ""
echo -e "${BOLD}Done!${RESET} Run ${GREEN}exec zsh${RESET} to reload."
echo ""
