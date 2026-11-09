#!/bin/sh
# ============================================================
# oh-my-bd — Installer (POSIX sh: works when piped to sh/dash/bash/zsh)
#
#   sh -c "$(curl -fsSL https://raw.githubusercontent.com/brxndxndiaz/oh-my-bd/main/install.sh)"
#
# Options / env:
#   --yes, -y          install optional tools without asking (OMBD_YES=1)
#   --no-deps          skip optional tools
#   OMBD_DIR=path      install location (default ~/.oh-my-bd)
#   OMBD_BRANCH=name   branch to install (default main)
# ============================================================

set -e

OMBD_DIR="${OMBD_DIR:-$HOME/.oh-my-bd}"
REPO_URL="${OMBD_REPO:-https://github.com/brxndxndiaz/oh-my-bd}"
BRANCH="${OMBD_BRANCH:-main}"
ZSHRC="${ZDOTDIR:-$HOME}/.zshrc"
MARK_BEGIN='# >>> oh-my-bd >>>'
MARK_END='# <<< oh-my-bd <<<'
YES="${OMBD_YES:-0}"
DEPS=1

for arg in "$@"; do
  case "$arg" in
    -y|--yes) YES=1 ;;
    --no-deps) DEPS=0 ;;
    -h|--help) sed -n '2,13p' "$0" 2>/dev/null | sed 's/^# \{0,1\}//'; exit 0 ;;
  esac
done

if [ -t 1 ] && [ -z "${NO_COLOR:-}" ]; then
  RED=$(printf '\033[0;31m'); GREEN=$(printf '\033[0;32m'); YELLOW=$(printf '\033[0;33m')
  BLUE=$(printf '\033[0;34m'); BOLD=$(printf '\033[1m'); RESET=$(printf '\033[0m')
else
  RED=''; GREEN=''; YELLOW=''; BLUE=''; BOLD=''; RESET=''
fi

ok()   { printf '  %s✓%s %s\n' "$GREEN" "$RESET" "$*"; }
skip() { printf '  %s−%s %s\n' "$YELLOW" "$RESET" "$*"; }
err()  { printf '  %s✗%s %s\n' "$RED" "$RESET" "$*" >&2; }
step() { printf '\n%s%s%s\n' "$BOLD" "$*" "$RESET"; }
has()  { command -v "$1" >/dev/null 2>&1; }

# Ask a yes/no question on the terminal even when stdin is a pipe.
ask() {
  [ "$YES" = 1 ] && return 0
  [ -r /dev/tty ] || return 1
  printf '  %s [y/N] ' "$1" > /dev/tty
  read -r answer < /dev/tty || return 1
  case "$answer" in y|Y|yes|YES) return 0 ;; *) return 1 ;; esac
}

pkg_manager() {
  for m in brew apt-get dnf pacman apk zypper; do
    if has "$m"; then echo "$m"; return; fi
  done
}

SUDO=''
if [ "$(id -u)" -ne 0 ] && has sudo; then SUDO='sudo'; fi

install_pkg() {  # cmd label package
  if has "$1"; then ok "$2"; return 0; fi
  manager="$(pkg_manager)"
  if [ -z "$manager" ]; then skip "$2 (no package manager found)"; return 0; fi
  if ask "Install $2?"; then
    if case "$manager" in
      brew)    brew install "$3" ;;
      apt-get) $SUDO apt-get install -y "$3" ;;
      dnf)     $SUDO dnf install -y "$3" ;;
      pacman)  $SUDO pacman -S --noconfirm "$3" ;;
      apk)     $SUDO apk add "$3" ;;
      zypper)  $SUDO zypper install -y "$3" ;;
    esac; then ok "$2 installed"; else skip "$2 failed to install"; fi
  else
    skip "$2 skipped"
  fi
}

printf '%s' "$BLUE"
cat <<'EOF'

       ______     __  __        __    __     __  __        ______     ___
      /\  __ \   /\ \_\ \      /\ "-./  \   /\ \_\ \      /\  == \   /\  __-.
      \ \ \/\ \  \ \  __ \     \ \ \-./\ \  \ \____ \     \ \  __<   \ \ \/\ \
       \ \_____\  \ \_\ \_\     \ \_\ \ \_\  \/\_____\     \ \_____\  \ \____-
        \/_____/   \/_/\/_/      \/_/  \/_/   \/_____/      \/_____/   \/____/
EOF
printf '%s\n' "$RESET"

# ------------------------------------------------------------
step "[1/4] Required"
if has zsh; then ok "zsh"; else
  err "zsh is required — install it first: https://github.com/ohmyzsh/ohmyzsh/wiki/Installing-ZSH"
  exit 1
fi
if has git; then ok "git"; else
  err "git is required — https://git-scm.com/downloads"
  exit 1
fi

# ------------------------------------------------------------
step "[2/4] Optional tools"
if [ "$DEPS" = 1 ]; then
  install_pkg fzf        "fzf (fuzzy pickers)"     fzf
  install_pkg fd         "fd (fast file finder)"   fd
  install_pkg tree       "tree"                    tree
  install_pkg lazydocker "lazydocker"              lazydocker
  install_pkg thefuck    "thefuck"                 thefuck
else
  skip "skipped (--no-deps)"
fi
# Debian/Ubuntu name the fd binary fdfind.
if ! has fd && has fdfind; then
  mkdir -p "$HOME/.local/bin" && ln -sf "$(command -v fdfind)" "$HOME/.local/bin/fd" && ok "fd → fdfind"
fi

# ------------------------------------------------------------
step "[3/4] oh-my-bd"
if [ -d "$OMBD_DIR/.git" ]; then
  ok "already installed at $OMBD_DIR — updating"
  git -C "$OMBD_DIR" pull --ff-only --quiet origin "$BRANCH" || skip "could not fast-forward (local changes?) — run: omb update"
elif [ -e "$OMBD_DIR" ]; then
  err "$OMBD_DIR exists but is not a git checkout. Move it away and re-run."
  exit 1
else
  git clone --quiet --depth 1 --branch "$BRANCH" "$REPO_URL" "$OMBD_DIR"
  ok "cloned to $OMBD_DIR"
fi
chmod +x "$OMBD_DIR/bin/oh-my-bd"
mkdir -p "$HOME/.local/bin"
ln -sf "$OMBD_DIR/bin/oh-my-bd" "$HOME/.local/bin/oh-my-bd"
ln -sf "$OMBD_DIR/bin/oh-my-bd" "$HOME/.local/bin/omb"
ok "CLI → ~/.local/bin/omb"

# ------------------------------------------------------------
step "[4/4] Shell config"
touch "$ZSHRC"
if grep -qxF "$MARK_BEGIN" "$ZSHRC"; then
  ok ".zshrc already configured"
elif grep -qF 'alias omb="oh-my-bd"' "$ZSHRC"; then
  # v1 block present: let the CLI migrate it (keeps a backup).
  export OMBD_DIR
  zsh "$OMBD_DIR/bin/oh-my-bd" migrate-zshrc >/dev/null 2>&1 || true
  if grep -qxF "$MARK_BEGIN" "$ZSHRC"; then ok "migrated old .zshrc block"; else skip "could not migrate old block — run: omb update"; fi
else
  {
    printf '\n%s\n' "$MARK_BEGIN"
    printf 'export OMBD_DIR="%s"\n' "$OMBD_DIR"
    # shellcheck disable=SC2016 # written literally into .zshrc
    printf '%s\n' '[[ ":$PATH:" == *":$HOME/.local/bin:"* ]] || export PATH="$HOME/.local/bin:$PATH"'
    # shellcheck disable=SC2016
    printf '%s\n' '[[ -f "$OMBD_DIR/lib/core.zsh" ]] && source "$OMBD_DIR/lib/core.zsh"'
    printf '%s\n' "$MARK_END"
  } >> "$ZSHRC"
  ok "added to $ZSHRC"
fi

FISH_CONFIG="${XDG_CONFIG_HOME:-$HOME/.config}/fish/config.fish"
if has fish; then
  if grep -q 'oh-my-bd.fish' "$FISH_CONFIG" 2>/dev/null; then
    ok "fish already configured"
  else
    mkdir -p "$(dirname "$FISH_CONFIG")"
    printf '\n# oh-my-bd Fish integration\ntest -f %s/oh-my-bd.fish; and source %s/oh-my-bd.fish\n' \
      "$OMBD_DIR" "$OMBD_DIR" >> "$FISH_CONFIG"
    ok "fish → $FISH_CONFIG"
  fi
fi

printf '\n%sDone!%s Run %sexec zsh%s, then type %somb%s to explore.\n\n' \
  "$BOLD" "$RESET" "$GREEN" "$RESET" "$GREEN" "$RESET"
