# ============================================================
# oh-my-bd — git.zsh — Git shortcuts
# ============================================================

# --- STATUS ---
status() {
  git status -sb
}

# --- ADD ---
add() {
  if [[ -z "$1" ]]; then
    git add .
  else
    git add "$@"
  fi
}

# --- COMMIT ---
commit() {
  if [[ -z "$1" ]]; then
    echo "Usage: commit <message>"
    return 1
  fi
  if [[ -z "$(git diff --cached)" ]]; then
    git add .
  fi
  git commit -m "$*"
}

# --- SWITCH ---
switch() {
  git switch "$1" 2>/dev/null || git switch -c "$1"
}

# --- BRANCHES ---
branches() {
  git for-each-ref --sort=refname --format='%(refname:short)' refs/heads refs/remotes
}

# --- CREATE + SWITCH ---
create() {
  git switch -c "$1"
}

# --- SYNC ---
sync() {
  git pull --rebase --autostash && git push
}

# --- FETCH ---
fetch() {
  git fetch --all --prune
}

# --- PUSH ---
push() {
  git push
}

# --- PULL ---
pull() {
  git pull --rebase --autostash
}

# --- LOG ---
log() {
  GIT_PAGER=cat command git log --oneline --graph --decorate --all
}

# --- UNDO ---
undo() {
  git reset --soft HEAD~1
}

# --- DISCARD ---
discard() {
  git reset --hard HEAD
}

# --- UPDATE ---
update() {
  local base="main"
  git show-ref --verify --quiet refs/remotes/origin/main || base="master"
  git stash push -u -m "auto-stash" >/dev/null 2>&1
  git fetch origin
  git rebase "origin/$base"
  git stash pop >/dev/null 2>&1
}

# --- REWRITE ---
rewrite() {
  git push --force-with-lease
}

# --- STASH ---
stash() {
  git stash "$@"
}

unstash() {
  local idx="${1:-0}"
  git stash pop "stash@{$idx}"
}

# --- TAGS ---
tags() {
  git tag -n --sort=-version:refname | while read -r tag msg; do
    printf "  ${CYAN}%s${RESET}  ${DIM}%s${RESET}\n" "$tag" "$msg"
  done
}

tag() {
  local name="${1:-}"
  if [[ -z "$name" ]]; then
    echo "Usage: tag <name>"
    return 1
  fi
  git tag -a "$name" -m "Tag: $name"
  printf "${GREEN}Created tag:${RESET} %s\n" "$name"
  printf "Push with: ${CYAN}git push origin %s${RESET}\n" "$name"
}

release() {
  local bump="${1:-patch}"
  if [[ "$bump" != "patch" && "$bump" != "minor" && "$bump" != "major" ]]; then
    echo "Usage: release [patch|minor|major]"
    return 1
  fi

  printf "${YELLOW}Running release...${RESET}\n"
  if "${OMBD_DIR}/release.sh" "$bump" 2>/dev/null; then
    printf "${GREEN}Release ready!${RESET}\n\n"
    printf "Push with: ${CYAN}git push origin v* --follow-tags${RESET}\n"
  else
    printf "${RED}Release failed. Check release.sh exists.${RESET}\n"
    return 1
  fi
}
