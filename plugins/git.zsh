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
  local branch="$1"

  if [[ -z "$branch" ]]; then
    local result
    result=$(
      git for-each-ref --sort=refname --format='%(refname:short)' refs/heads |
      fzf --height=70% \
        --prompt="Switch to branch: " \
        --expect=ctrl-n \
        --layout=reverse \
        --header="Ctrl+N: create new branch"
    )
    
    echo "" # newline after fzf
    
    if [[ -z "$result" ]]; then
      return 0
    fi
    
    local key selected
    key="${result%%$'\n'*}"
    selected="${result#*$'\n'}"
    
    if [[ "$key" == "ctrl-n" ]]; then
      local new_branch
      echo -n "Create new branch: "
      read new_branch
      if [[ -n "$new_branch" ]]; then
        git switch -c "$new_branch"
      fi
    elif [[ -n "$selected" ]]; then
      git switch "$selected"
    fi
    return 0
  fi

  if git show-ref --verify --quiet "refs/heads/$branch"; then
    git switch "$branch"
  elif git show-ref --verify --quiet "refs/remotes/origin/$branch"; then
    git switch --track "origin/$branch"
  else
    git switch -c "$branch"
  fi
}

# --- BRANCH ---
branch() {
  local cmd="${1:-}"
  
  if [[ "$cmd" == "help" ]]; then
    cat << 'EOF'
branch — Git branch manager

Usage:
  branch            Show current branch
  branch ls        List all branches
  branch new <name> Create and switch to new branch
  branch rm <name> Delete local branch
  branch rename <new> Rename current branch
  branch track <remote>  Set upstream tracking
EOF
    return
  fi
  
  case "$cmd" in
    ls|"")
      if [[ -t 1 ]] && command -v fzf >/dev/null 2>&1 && [[ -n "$FZF_DEFAULT_COMMAND" || -x "$(command -v fzf 2>/dev/null)" ]]; then
        git for-each-ref --sort=refname --format='%(refname:short)' refs/heads refs/remotes |
          fzf --height=60% --prompt="Branches: " --layout=reverse
      else
        git for-each-ref --sort=refname --format='%(refname:short)' refs/heads refs/remotes
      fi
      ;;
    new)
      [[ -z "$2" ]] && echo "Usage: branch new <name>" && return 1
      git switch -c "$2"
      ;;
    rm)
      [[ -z "$2" ]] && echo "Usage: branch rm <name>" && return 1
      git branch -d "$2"
      ;;
    rename)
      [[ -z "$2" ]] && echo "Usage: branch rename <new-name>" && return 1
      git branch -m "$2"
      ;;
    track)
      [[ -z "$2" ]] && echo "Usage: branch track <remote-branch>" && return 1
      git branch --set-upstream-to="origin/$2"
      ;;
    *)
      git branch --show-current
      ;;
  esac
}

# --- BRANCHES ---
branches() {
  if [[ -t 1 ]] && command -v fzf >/dev/null 2>&1; then
    local result
    result=$(git for-each-ref --sort=refname --format='%(refname:short)' refs/heads refs/remotes |
      fzf --height=70% --prompt="Switch branch: " --layout=reverse --expect=enter)
    echo ""
    if [[ -z "$result" ]]; then return 0; fi
    local key="${result%%$'\n'*}"
    local selected="${result#*$'\n'}"
    if [[ "$key" == "enter" || -n "$selected" ]]; then
      git switch "$selected"
    fi
  else
    git for-each-ref --sort=refname --format='%(refname:short)' refs/heads refs/remotes
  fi
}

# --- CHANGED ---
changed() {
  git diff --name-only HEAD
}

# --- ROOT ---
root() {
  cd "$(git rev-parse --show-toplevel 2>/dev/null)" || echo "Not a git repository"
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

# --- REPO ---
repo() {
  local cmd="${1:-}"
  
  if [[ "$cmd" == "help" ]]; then
    cat << 'EOF'
repo — Git repository utilities

Usage:
  repo            Repo summary
  repo root       Jump to git root
  repo open       Open origin URL in browser
  repo name       Print owner/repo
  repo main      Detect default branch name
  repo url       Print origin URL
  repo pr        Open PR creation page
  repo issues    Open issues page
EOF
    return
  fi
  
  case "$cmd" in
    root)
      local root_dir
      root_dir="$(git rev-parse --show-toplevel 2>/dev/null)"
      if [[ -n "$root_dir" ]]; then
        cd "$root_dir"
      else
        echo "Not a git repository"
        return 1
      fi
      ;;
    open)
      git remote get-url origin 2>/dev/null | xargs open 2>/dev/null || \
        { echo "No remote URL found"; return 1; }
      ;;
    name)
      git remote get-url origin 2>/dev/null |
        sed 's/.*[\/:]\([^\/]*\)\/\([^.]*\).*/\1\/\2/'
      ;;
    main)
      local remote
      remote="$(git remote 2>/dev/null | head -1)"
      if [[ -n "$remote" ]]; then
        git symbolic-ref "refs/remotes/$remote/HEAD" 2>/dev/null |
          sed "s|refs/remotes/$remote/||"
      else
        echo "main"
      fi
      ;;
    url)
      git remote get-url "${2:-origin}" 2>/dev/null
      ;;
    pr)
      local url branch
      url="$(git remote get-url origin 2>/dev/null | sed 's/\.git$//')"
      branch="$(git branch --show-current 2>/dev/null)"
      open "${url}/compare/main...${branch}?expand=1" 2>/dev/null
      ;;
    issues)
      local url
      url="$(git remote get-url origin 2>/dev/null | sed 's/\.git$//')"
      open "${url}/issues" 2>/dev/null
      ;;
    *)
      local branch url
      branch="$(git branch --show-current 2>/dev/null || echo "(detached)")"
      url="$(git remote get-url origin 2>/dev/null | sed 's/\.git$//')"
      echo "repo   : $url"
      echo "branch : $branch"
      ;;
  esac
}

# --- WORK ---
work() {
  local branch dirty docker_ctx env_file
  
  branch="$(git branch --show-current 2>/dev/null || echo "detached")"
  if git diff --quiet HEAD 2>/dev/null; then
    dirty="${GREEN}clean${RESET}"
  else
    dirty="${YELLOW}dirty${RESET}"
  fi
  
  docker_ctx="$(command docker context show 2>/dev/null || echo "unknown")"
  
  if [[ -f .env ]]; then
    env_file="${GREEN}.env${RESET}"
  else
    env_file="${DIM}no .env${RESET}"
  fi
  
  echo ""
  echo "  branch    $branch"
  echo "  status   $dirty"
  echo "  docker   $docker_ctx"
  echo "  env      $env_file"
  echo ""
}

# --- RECENT ---
recent() {
  if [[ ! -f "$HOME/.cdc_dirs" ]]; then
    echo "No recent bookmarks. Add: cdc add <name> <path>"
    return
  fi
  
  if command -v fzf >/dev/null 2>&1; then
    local result
    result=$(awk -F'|' '{print $1 " -> " $2}' "$HOME/.cdc_dirs" |
      tac | head -10 |
      fzf --height=50% --prompt="Recent: " --layout=reverse)
    if [[ -n "$result" ]]; then
      local target="${result#*-> }"
      target="${target#"${target%%[![:space:]]*}"}"
      cd "$target" 2>/dev/null || { echo "Not found: $target"; return 1; }
    fi
  else
    echo "Recent cdc targets:"
    tac "$HOME/.cdc_dirs" 2>/dev/null | head -10 | while IFS='|' read -r name dir; do
      echo "  $name -> $dir"
    done
  fi
}

# --- PRUNE ---
prune() {
  echo "Fetching and pruning..."
  git fetch --all --prune 2>/dev/null
  echo ""
  echo "Gone remote branches:"
  git branch -vv 2>/dev/null | grep ':gone]' | awk '{print "  " $1}'
  echo ""
  echo "Run 'git branch -D <name>' to delete a gone branch."
}

# --- PUBLISH ---
publish() {
  local branch
  branch="$(git branch --show-current 2>/dev/null)"
  if [[ -z "$branch" ]]; then
    echo "No current branch"
    return 1
  fi
  
  if git config "branch.${branch}.merge" >/dev/null 2>&1; then
    echo "Already publishing: $branch"
    git push
  else
    echo "First push: $branch"
    git push -u origin "$branch"
  fi
}

# --- BROWSE ---
browse() {
  local cmd="${1:-}"
  local url base
  
  base="$(git remote get-url origin 2>/dev/null | sed 's/\.git$//')"
  if [[ -z "$base" ]]; then
    echo "No origin remote"
    return 1
  fi
  
  case "$cmd" in
    pr)
      local branch
      branch="$(git branch --show-current 2>/dev/null)"
      url="${base}/compare/main...${branch}?expand=1"
      ;;
    issues)
      url="${base}/issues"
      ;;
    actions)
      url="${base}/actions"
      ;;
    releases)
      url="${base}/releases"
      ;;
    *)
      url="$base"
      ;;
  esac
  
  open "$url" 2>/dev/null || echo "Open: $url"
}

