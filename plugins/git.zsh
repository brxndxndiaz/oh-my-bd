# ============================================================
# oh-my-bd — git.zsh — Git shortcuts
# ============================================================

ombd_has git || return 0

# Branches, most recently committed first. Local branches by name; remote
# branches only when there is no local branch of the same name. Remote
# HEAD symrefs (the bare "origin" entry) are skipped.
function ombd_git_branch_refs {
  local -A seen
  local ref name
  git for-each-ref --sort=-committerdate --format='%(refname)' refs/heads refs/remotes 2>/dev/null |
  while IFS= read -r ref; do
    case "$ref" in
      refs/remotes/*/HEAD) continue ;;
      refs/heads/*) name="${ref#refs/heads/}"; seen[$name]=1; print -r -- "$name" ;;
      refs/remotes/*)
        name="${ref#refs/remotes/}"
        (( ${+seen[${name#*/}]} )) && continue
        seen[${name#*/}]=1
        print -r -- "$name" ;;
    esac
  done
}

# Pick a branch interactively (fzf with log preview, or numbered menu).
function _ombd_git_pick_branch {
  local prompt="${1:-Branch:}"
  ombd_git_branch_refs | grep -vx -- "$(git branch --show-current 2>/dev/null)" |
    ombd_pick "$prompt" --preview='git log --oneline --graph --color=always -20 {} --' \
      --preview-window=right:55%
}

# Switch to a branch name as shown by ombd_git_branch_refs. Handles
# "origin/foo" by tracking it instead of creating a branch called origin/foo.
# Ask a remote whether it has <branch>, fetching it into refs/remotes/<remote>/
# so it can be tracked. Never prompts for credentials (fails quietly offline).
function _ombd_git_fetch_branch {
  local remote="$1" branch="$2"
  GIT_TERMINAL_PROMPT=0 git fetch --quiet "$remote" \
    "+refs/heads/${branch}:refs/remotes/${remote}/${branch}" 2>/dev/null
}

# True when a local branch was created and never committed to (its reflog
# holds only the "Created from" entry) — i.e. it's safe to repoint it.
function _ombd_git_branch_untouched {
  local -a log; log=("${(@f)$(git reflog show --format=%gs "refs/heads/$1" -- 2>/dev/null)}")
  (( ${#log} == 1 )) && [[ "${log[1]}" == "branch: Created from"* ]]
}

# The current branch has no upstream but <remote>/<same name> exists: usually
# the branch was created before the remote one had been fetched. Connect them.
function _ombd_git_adopt_remote {
  local branch="$1" remote="${2:-origin}"
  git show-ref --verify --quiet "refs/remotes/$remote/$branch" || return 1
  if _ombd_git_branch_untouched "$branch"; then
    print "${OMBD_C_YELLOW}'$branch' was created locally before the remote branch was fetched.${OMBD_C_RESET}"
    if ombd_confirm "Point it at $remote/$branch and track it? (uncommitted changes are kept)" y; then
      git reset --keep "$remote/$branch" && git branch --quiet --set-upstream-to="$remote/$branch" &&
        print "Now tracking $remote/$branch."
      return
    fi
    return 1
  fi
  # It has commits of its own: just connect it; the next pull rebases them.
  git branch --quiet --set-upstream-to="$remote/$branch" && print "Now tracking $remote/$branch."
}

function _ombd_git_switch_to {
  local branch="$1" remote rest
  [[ -z "$branch" ]] && return 1
  if git show-ref --verify --quiet "refs/heads/$branch"; then
    git switch "$branch" || return
    # No upstream yet? Connect it if the remote has the same branch.
    if ! git rev-parse --abbrev-ref '@{u}' >/dev/null 2>&1; then
      for remote in ${(f)"$(git remote)"}; do
        _ombd_git_fetch_branch "$remote" "$branch" && { _ombd_git_adopt_remote "$branch" "$remote"; break; }
      done
    fi
    return 0
  fi
  remote="${branch%%/*}" rest="${branch#*/}"
  if [[ "$branch" == */* ]] && git remote | grep -qx -- "$remote" &&
     git show-ref --verify --quiet "refs/remotes/$branch"; then
    if git show-ref --verify --quiet "refs/heads/$rest"; then
      _ombd_git_switch_to "$rest"
    else
      git switch --track "$branch"
    fi
    return
  fi
  local r
  for r in ${(f)"$(git remote)"}; do
    if git show-ref --verify --quiet "refs/remotes/$r/$branch"; then
      git switch --track "$r/$branch"; return
    fi
  done
  # Not known locally: the remote may have it even though we haven't fetched yet.
  for r in ${(f)"$(git remote)"}; do
    if _ombd_git_fetch_branch "$r" "$branch"; then
      git switch --track "$r/$branch"; return
    fi
  done
  print "${OMBD_C_DIM}'$branch' isn't on any remote — creating it from $(git branch --show-current 2>/dev/null || print HEAD).${OMBD_C_RESET}"
  git switch -c "$branch"
}

# --- STATUS ---
function status { git status -sb "$@"; }

# Porcelain -z gives the destination first, followed by the original on renames.
# Quote for the line-oriented picker so unusual names survive selection.
function _ombd_git_status_paths {
  local status_records="$1" record filename original
  while IFS= read -r -d '' record; do
    filename="${record[4,-1]}"
    if [[ "${record[1,2]}" == *[RC]* ]]; then
      IFS= read -r -d '' original || break
    fi
    if [[ "$2" == picker ]]; then
      print -r -- "${(q+)filename}"
    else
      print -r -- "$filename"
    fi
  done <<< "$status_records"
}

# --- ADD ---  `add` stages everything; `add <files>` stages those;
# `add -i` picks files interactively (multi-select with diff preview).
function add {
  if [[ "$1" == -i || "$1" == pick ]]; then
    local root records
    root="$(git rev-parse --show-toplevel)" || return 1
    records="$(git -C "$root" status --porcelain -z --untracked-files=all)" || return 1
    local -a files
    files=("${(@f)$(cd -q -- "$root" && _ombd_git_status_paths "$records" picker | ombd_pick 'Stage:' --multi \
      --preview="zsh -fc 'p=\${(Q)1}; git --literal-pathspecs diff --color=always -- \"\$p\" | head -200; git diff --no-index --color=always /dev/null \"\$p\" 2>/dev/null | head -200' -- {}")}")
    files=(${files:#})
    (( ${#files} )) && git --literal-pathspecs -C "$root" add -- "${(@Q)files}" && git status -sb
    return
  fi
  if (( $# == 0 )); then git add -A; else git add -- "$@"; fi
}

# --- COMMIT --- `commit msg words` (auto-stages all if nothing is staged);
# `commit` alone opens your editor.
function commit {
  if git diff --cached --quiet 2>/dev/null; then
    git add -A
  fi
  if (( $# == 0 )); then git commit; else git commit -m "$*"; fi
}

# --- SWITCH --- `switch` opens a picker (type a new name + Tab to create it).
# Branch list for the picker, runnable in a fresh zsh (fzf reload).
typeset -g _ombd_branch_list_cmd='source "$OMBD_DIR/lib/utils.zsh"; source "$OMBD_DIR/plugins/git.zsh"; ombd_git_branch_refs | grep -vx -- "$(git branch --show-current 2>/dev/null)"'

function switch {
  local branch="$1"
  if [[ -z "$branch" ]]; then
    if ombd_use_fzf; then
      local out key query sel
      out="$(ombd_git_branch_refs | grep -vx -- "$(git branch --show-current 2>/dev/null)" |
        fzf --height=70% --layout=reverse --border --prompt='Switch: ' --print-query \
          --expect=tab \
          --bind "start:reload:GIT_TERMINAL_PROMPT=0 git fetch --quiet --prune 2>/dev/null; zsh -fc ${(qq)_ombd_branch_list_cmd}" \
          --header='Enter: switch · Tab: new branch named as typed' \
          --preview='git log --oneline --graph --color=always -20 {} --' --preview-window=right:55%)"
      local -a lines; lines=("${(@f)out}")       # keep empty lines (empty key = Enter)
      query="${lines[1]}" key="${lines[2]}" sel="${lines[3]}"
      if [[ "$key" == tab ]]; then
        [[ -n "$query" ]] && git switch -c "$query"
        return
      fi
      branch="${sel:-$query}"
      [[ -z "$branch" ]] && return 0
    else
      branch="$(_ombd_git_pick_branch 'Switch to')" || return 0
    fi
  fi
  _ombd_git_switch_to "$branch"
}

# --- CREATE + SWITCH ---
function create {
  [[ -z "$1" ]] && { print "Usage: create <branch>"; return 1; }
  git switch -c "$1"
}

# --- BRANCHES --- pick and switch
function branches {
  if ombd_interactive; then
    local b
    b="$(_ombd_git_pick_branch 'Switch to')" && _ombd_git_switch_to "$b"
  else
    ombd_git_branch_refs
  fi
}

# --- BRANCH ---
function branch {
  case "${1:-}" in
    help|-h)
      cat <<'EOF'
branch — Git branch manager

  branch                 Show current branch
  branch ls              List branches (recent first)
  branch new <name>      Create and switch
  branch rm [name]       Delete a local branch (picker if no name)
  branch rename <new>    Rename current branch
  branch track [remote]  Set upstream to <remote>/<current> (default origin)
EOF
      ;;
    ls|list) ombd_git_branch_refs ;;
    new)
      [[ -z "$2" ]] && { print "Usage: branch new <name>"; return 1; }
      git switch -c "$2" ;;
    rm|delete)
      local b="$2"
      if [[ -z "$b" ]]; then
        b="$(git for-each-ref --format='%(refname:short)' refs/heads |
          grep -vx -- "$(git branch --show-current)" | ombd_pick 'Delete branch:')" || return 0
      fi
      if ! git branch -d -- "$b"; then
        ombd_confirm "'$b' is not fully merged. Force delete?" && git branch -D -- "$b"
      fi ;;
    rename)
      [[ -z "$2" ]] && { print "Usage: branch rename <new-name>"; return 1; }
      git branch -m -- "$2" ;;
    track)
      local cur; cur="$(git branch --show-current)"
      git branch --set-upstream-to="${2:-origin}/$cur" ;;
    "") git branch --show-current ;;
    *) git branch "$@" ;;
  esac
}

# --- CHANGED --- list changed + untracked files; interactive: pick → open in $EDITOR
function changed {
  local root records
  root="$(git rev-parse --show-toplevel)" || return 1
  records="$(git -C "$root" status --porcelain -z --untracked-files=all)" || return 1
  [[ -z "$records" ]] && { print "Working tree clean."; return 0; }
  if ombd_use_fzf; then
    local -a files
    files=("${(@f)$(cd -q -- "$root" && _ombd_git_status_paths "$records" picker |
      fzf --multi --height=70% --layout=reverse --border \
        --prompt='Changed: ' --header='Enter: open in editor  •  Tab: multi-select' \
        --preview="zsh -fc 'p=\${(Q)1}; git --literal-pathspecs diff --color=always HEAD -- \"\$p\" 2>/dev/null | head -300; if [[ -f \$p ]] && ! git --literal-pathspecs ls-files --error-unmatch -- \"\$p\" >/dev/null 2>&1; then head -100 -- \"\$p\"; fi' -- {}" \
        --preview-window=right:60%)}")
    files=(${files:#})
    files=("${(@Q)files}")
    (( ${#files} )) && ${=EDITOR:-vi} -- "${(@)files/#/$root/}"
  else
    _ombd_git_status_paths "$records"
  fi
}

# --- ROOT ---
function root {
  local top
  top="$(git rev-parse --show-toplevel 2>/dev/null)" || { print "Not a git repository"; return 1; }
  cd "$top"
}

function gsync { git pull --rebase --autostash && git push; }
function fetch { git fetch --all --prune "$@"; }
push()  { git push "$@"; }
# `pull` on a branch with no upstream connects it to the remote branch of the
# same name first (instead of git's "no tracking information" error).
function pull {
  if (( $# == 0 )) && ! git rev-parse --abbrev-ref '@{u}' >/dev/null 2>&1; then
    local b; b="$(git branch --show-current 2>/dev/null)"
    [[ -z "$b" ]] && { print "Not on a branch."; return 1; }
    if _ombd_git_fetch_branch origin "$b"; then
      _ombd_git_adopt_remote "$b" origin || return 1
    else
      print "'$b' isn't on origin yet. Push it with: publish"
      return 1
    fi
  fi
  git pull --rebase --autostash "$@"
}

# --- LOG --- git graph inside a repo; falls through to the system `log`
# (macOS unified logging) outside a repo or for its subcommands.
function log {
  case "$1" in
    show|stream|stats|collect|config|erase) command log "$@"; return ;;
  esac
  if ombd_in_git; then
    git log --oneline --graph --decorate --color=auto "$@"
  elif (( $+commands[log] )); then
    command log "$@"
  else
    print "Not a git repository"; return 1
  fi
}

# --- UNDO --- undo last commit, keep the changes staged
function undo {
  git log -1 --oneline || return 1
  git reset --soft HEAD~1 && print "Undone. Changes are still staged."
}

# --- DISCARD ---  `discard <files>` restores just those files;
# `discard` alone discards ALL uncommitted changes after confirmation.
function discard {
  if (( $# )); then
    git restore --staged --worktree -- "$@" 2>/dev/null || git checkout HEAD -- "$@"
    return
  fi
  local changes
  changes="$(git status --short --untracked-files=no)"
  [[ -z "$changes" ]] && { print "Nothing to discard."; return 0; }
  print -r -- "$changes"
  ombd_confirm "$(ombd_color red 'Discard ALL changes above?') This cannot be undone." || return 1
  git reset --hard HEAD
}

# --- UPDATE --- rebase current branch onto the remote default branch
function update {
  local base; base="$(ombd_default_branch)"
  git fetch origin "$base" || return 1
  git rebase --autostash "origin/$base"
}

# --- REWRITE --- safe force push
function rewrite { git push --force-with-lease "$@"; }

# --- STASH ---
function stash { git stash "$@"; }

# `unstash` with no argument: pick a stash (preview shows its diff).
function unstash {
  local idx="$1"
  if [[ -z "$idx" ]]; then
    [[ -z "$(git stash list)" ]] && { print "No stashes."; return 0; }
    if ombd_interactive; then
      local sel
      sel="$(git stash list | ombd_pick 'Apply stash:' --preview='git stash show -p --color=always {1}' \
        --delimiter=':')" || return 0
      idx="${sel%%:*}"
      git stash pop "$idx"; return
    fi
    idx=0
  fi
  [[ "$idx" == <-> ]] && idx="stash@{$idx}"
  git stash pop "$idx"
}

# --- TAGS ---
function tags {
  git tag -n --sort=-version:refname | while read -r t msg; do
    printf "  %s%s%s  %s%s%s\n" "$OMBD_C_CYAN" "$t" "$OMBD_C_RESET" "$OMBD_C_DIM" "$msg" "$OMBD_C_RESET"
  done
}

function tag {
  [[ -z "$1" ]] && { print "Usage: tag <name> [message]"; return 1; }
  local name="$1"; shift
  git tag -a "$name" -m "${*:-$name}" || return 1
  print "${OMBD_C_GREEN}Created tag:${OMBD_C_RESET} $name"
  print "Push with: ${OMBD_C_CYAN}git push origin $name${OMBD_C_RESET}"
}

# --- RELEASE --- bump the latest vX.Y.Z tag and create an annotated tag
function release {
  local bump="${1:-patch}"
  [[ "$bump" == (patch|minor|major) ]] || { print "Usage: release [patch|minor|major]"; return 1; }
  local last; last="$(git tag --list 'v[0-9]*' --sort=-version:refname | head -1)"
  local v="${${last:-v0.0.0}#v}" maj min pat
  maj="${v%%.*}"; v="${v#*.}"; min="${v%%.*}"; pat="${${v#*.}%%[^0-9]*}"
  case "$bump" in
    major) (( maj++, min = 0, pat = 0 )) ;;
    minor) (( min++, pat = 0 )) ;;
    patch) (( pat++ )) ;;
  esac
  local next="v$maj.$min.$pat"
  print "Last release: ${last:-none}  →  ${OMBD_C_GREEN}$next${OMBD_C_RESET}"
  [[ -n "$last" ]] && git log --oneline "$last"..HEAD | head -20
  ombd_confirm "Create tag $next?" y || return 1
  git tag -a "$next" -m "Release $next" || return 1
  print "Push with: ${OMBD_C_CYAN}git push origin $next${OMBD_C_RESET}"
}

# --- REPO ---
function repo {
  local web
  case "${1:-}" in
    help|-h)
      cat <<'EOF'
repo — Git repository utilities

  repo           Repo summary
  repo root      Jump to git root
  repo open      Open repository in browser
  repo name      Print owner/repo
  repo main      Print default branch
  repo url       Print web URL
  repo pr        Open PR page for current branch
  repo issues    Open issues page
EOF
      ;;
    root) root ;;
    open) browse ;;
    pr) browse pr ;;
    issues) browse issues ;;
    main) ombd_default_branch ;;
    url) ombd_remote_web_url "${2:-origin}" ;;
    name)
      web="$(ombd_remote_web_url)" || return 1
      print -r -- "${${web#*://}#*/}" ;;
    "")
      web="$(ombd_remote_web_url)"
      print "repo    : ${web:-(no origin)}"
      print "branch  : $(git branch --show-current 2>/dev/null || print detached)"
      print "default : $(ombd_default_branch)"
      local ab; ab="$(git rev-list --left-right --count @{u}...HEAD 2>/dev/null)"
      [[ -n "$ab" ]] && print "behind/ahead: ${ab//$'\t'/ / }"
      ;;
    *) print "Unknown: repo $1 (try: repo help)"; return 1 ;;
  esac
}

# --- WORK --- one-glance status
function work {
  local branch dirty docker_ctx env_file
  branch="$(git branch --show-current 2>/dev/null)"
  [[ -z "$branch" ]] && branch="${OMBD_C_DIM}(not a repo / detached)${OMBD_C_RESET}"
  if ! ombd_in_git; then dirty="${OMBD_C_DIM}-${OMBD_C_RESET}"
  elif [[ -z "$(git status --porcelain 2>/dev/null)" ]]; then dirty="${OMBD_C_GREEN}clean${OMBD_C_RESET}"
  else dirty="${OMBD_C_YELLOW}dirty ($(git status --porcelain | wc -l | tr -d ' ') files)${OMBD_C_RESET}"
  fi
  if ombd_has docker; then docker_ctx="$(command docker context show 2>/dev/null || print unknown)"
  else docker_ctx="${OMBD_C_DIM}n/a${OMBD_C_RESET}"; fi
  if [[ -f .env ]]; then env_file="${OMBD_C_GREEN}.env${OMBD_C_RESET}"
  else env_file="${OMBD_C_DIM}no .env${OMBD_C_RESET}"; fi
  print ""
  print "  branch   $branch"
  print "  status   $dirty"
  print "  docker   $docker_ctx"
  print "  env      $env_file"
  print ""
}

# --- PRUNE --- fetch, then offer to delete branches whose upstream is gone
function prune {
  git fetch --all --prune --quiet || return 1
  local -a gone
  gone=("${(@f)$(git for-each-ref --format='%(refname:short) %(upstream:track)' refs/heads |
    awk '$2 == "[gone]" {print $1}')}")
  gone=(${gone:#})
  (( ${#gone} )) || { print "No branches with a deleted upstream."; return 0; }
  print "Branches whose remote is gone:"
  print -rl -- "  "${^gone}
  local -a pick
  if ombd_use_fzf; then
    pick=("${(@f)$(print -rl -- "${gone[@]}" | fzf --multi --height=50% --layout=reverse --border \
      --prompt='Delete: ' --header='Tab: select  •  Enter: delete selected' --bind='ctrl-a:select-all')}")
    pick=(${pick:#})
  elif ombd_confirm "Delete all ${#gone} of them?"; then
    pick=("${gone[@]}")
  fi
  (( ${#pick} )) && git branch -D -- "${pick[@]}"
}

# --- PUBLISH --- push, setting upstream on first push
function publish {
  local branch; branch="$(git branch --show-current 2>/dev/null)"
  [[ -z "$branch" ]] && { print "No current branch"; return 1; }
  if git rev-parse --abbrev-ref '@{u}' >/dev/null 2>&1; then
    git push
  else
    git push -u origin "$branch"
  fi
}

# --- BROWSE --- open repo pages (works with ssh and https remotes)
function browse {
  local base url
  base="$(ombd_remote_web_url)" || { print "No origin remote"; return 1; }
  case "${1:-}" in
    pr)
      local branch; branch="$(git branch --show-current 2>/dev/null)"
      if [[ "$base" == *gitlab* ]]; then
        url="$base/-/merge_requests/new?merge_request%5Bsource_branch%5D=$branch"
      else
        url="$base/compare/$(ombd_default_branch)...$branch?expand=1"
      fi ;;
    issues)   url="$base/issues" ;;
    actions)  url="$base/actions" ;;
    releases) url="$base/releases" ;;
    file)     url="$base/blob/$(git branch --show-current)/$(git rev-parse --show-prefix)${2}" ;;
    "")       url="$base" ;;
    *) print "Usage: browse [pr|issues|actions|releases|file <path>]"; return 1 ;;
  esac
  ombd_open "$url"
}
