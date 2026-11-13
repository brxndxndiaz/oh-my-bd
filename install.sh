#!/bin/sh
# ============================================================
# oh-my-bd — Installer (POSIX sh: works when piped to sh/dash/bash/zsh)
#
#   sh -c "$(curl -fsSL https://raw.githubusercontent.com/brxndxndiaz/oh-my-bd/main/install.sh)"
#
# Options / env:
#   --yes, -y          install optional tools without asking (OMBD_YES=1)
#   --no-deps          skip optional tools
#   --deps-only        only check/install tools (what `omb deps` runs)
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
DEPS_ONLY=0

for arg in "$@"; do
  case "$arg" in
    -y|--yes) YES=1 ;;
    --no-deps) DEPS=0 ;;
    --deps-only) DEPS_ONLY=1 ;;
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

# Package name for a command on a given package manager ("" = not packaged there).
pkg_for() {  # cmd manager
  case "$1:$2" in
    fd:apt-get|fd:dnf)        echo fd-find ;;
    rg:*)                     echo ripgrep ;;
    lazydocker:apt-get|lazydocker:dnf|lazydocker:apk|lazydocker:zypper) echo '' ;;
    *)                        echo "$1" ;;
  esac
}

# Name a tool is installed under on Debian/Ubuntu, if different.
alt_name() {
  case "$1" in fd) echo fdfind ;; bat) echo batcat ;; *) echo "$1" ;; esac
}

APT_UPDATED=0
install_pkg() {  # cmd label
  if has "$1" || has "$(alt_name "$1")"; then ok "$2"; return 0; fi
  manager="$(pkg_manager)"
  if [ -z "$manager" ]; then skip "$2 (no package manager found)"; return 0; fi
  pkg="$(pkg_for "$1" "$manager")"
  if [ -z "$pkg" ]; then skip "$2 (not packaged for $manager — see its website)"; return 0; fi
  if ask "Install $2?"; then
    if [ "$manager" = apt-get ] && [ "$APT_UPDATED" = 0 ]; then
      $SUDO apt-get update -qq >/dev/null 2>&1 || true
      APT_UPDATED=1
    fi
    case "$manager" in
      brew)    brew install "$pkg" ;;
      apt-get) $SUDO apt-get install -y "$pkg" ;;
      dnf)     $SUDO dnf install -y "$pkg" ;;
      pacman)  $SUDO pacman -S --noconfirm "$pkg" ;;
      apk)     $SUDO apk add "$pkg" ;;
      zypper)  $SUDO zypper install -y "$pkg" ;;
    esac || true
    # Judge by the result, not the exit code: package managers can fail on an
    # unrelated post-install step after the tool itself installed fine.
    if has "$1" || has "$(alt_name "$1")"; then ok "$2 installed"; else skip "$2 failed to install"; fi
  else
    skip "$2 skipped"
  fi
}

# Debian/Ubuntu ship fd as `fdfind` and bat as `batcat`; expose the usual names.
link_renamed() {  # wanted actual
  if ! has "$1" && has "$2"; then
    mkdir -p "$HOME/.local/bin" && ln -sf "$(command -v "$2")" "$HOME/.local/bin/$1" && ok "$1 → $2"
  fi
}

if [ "$DEPS_ONLY" = 0 ]; then
printf '%s' "$BLUE"
cat <<'EOF'

       ______     __  __        __    __     __  __        ______     ___
      /\  __ \   /\ \_\ \      /\ "-./  \   /\ \_\ \      /\  == \   /\  __-.
      \ \ \/\ \  \ \  __ \     \ \ \-./\ \  \ \____ \     \ \  __<   \ \ \/\ \
       \ \_____\  \ \_\ \_\     \ \_\ \ \_\  \/\_____\     \ \_____\  \ \____-
        \/_____/   \/_/\/_/      \/_/  \/_/   \/_____/      \/_____/   \/____/
EOF
printf '%s\n' "$RESET"
fi

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
step "[2/4] Tools"
# Keep this list in sync with OMBD_TOOLS in lib/utils.zsh.
if [ "$DEPS" = 1 ]; then
  install_pkg fzf        "fzf — pickers and fuzzy search"
  install_pkg rg         "ripgrep — text search (Ctrl+F twice)"
  install_pkg fd         "fd — fast file search"
  install_pkg bat        "bat — syntax-highlighted previews"
  install_pkg tree       "tree — tre command"
  install_pkg lazydocker "lazydocker — lz command"
  install_pkg thefuck    "thefuck — tf command"
else
  skip "skipped (--no-deps)"
fi
link_renamed fd fdfind
link_renamed bat batcat

if [ "$DEPS_ONLY" = 1 ]; then
  printf '\n'
  exit 0
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
