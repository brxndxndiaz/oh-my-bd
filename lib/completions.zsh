# ============================================================
# oh-my-bd — completions.zsh — Tab completion for oh-my-bd commands
# ============================================================

# Make sure the completion system is running (oh-my-zsh, prezto, etc. have
# usually done this already; plain .zshrc setups often haven't).
if (( ! $+functions[compdef] )); then
  autoload -Uz compinit
  compinit -i -d "${ZDOTDIR:-$HOME}/.zcompdump"
fi

# Nicer completion menu (only if the user hasn't styled it themselves).
if ! zstyle -L ':completion:*' menu >/dev/null 2>&1; then
  zstyle ':completion:*' menu select
  zstyle ':completion:*' matcher-list 'm:{a-zA-Z}={A-Za-z}' 'r:|[._-]=* r:|=*'
  zstyle ':completion:*:descriptions' format '%F{cyan}-- %d --%f'
  zstyle ':completion:*' group-name ''
fi

# --- helpers ---
_ombd_branches() {
  local -a b; b=(${(f)"$(ombd_git_branch_refs 2>/dev/null)"})
  _describe -t branches 'branch' b
}
_ombd_local_branches() {
  local -a b; b=(${(f)"$(git for-each-ref --format='%(refname:short)' refs/heads 2>/dev/null)"})
  _describe -t branches 'local branch' b
}
_ombd_cdc_names() {
  local -a n
  [[ -f "$CDC_DIR" ]] && n=(${(f)"$(awk -F'|' 'NF { p=$0; sub(/^[^|]*\|/, "", p); gsub(/:/, "\\:", $1); print $1 ":" p }' "$CDC_DIR")"})
  _describe -t bookmarks 'bookmark' n
}

# --- omb / oh-my-bd ---
_ombd_omb() {
  local -a cmds; cmds=(
    'palette:fuzzy command palette'
    'list:list plugins or show plugin help'
    'search:search commands'
    'cheatsheet:one-page reference'
    'doctor:run diagnostics'
    'update:update oh-my-bd'
    'config:edit your config file'
    'add:create a custom plugin'
    'edit:edit a custom plugin'
    'remove:remove a custom plugin'
    'enable:enable a plugin'
    'disable:disable a plugin'
    'install:run the installer'
    'uninstall:remove oh-my-bd'
    'changelog:show recent changes'
    'version:show version'
    'help:show help'
  )
  if (( CURRENT == 2 )); then
    _describe -t commands 'omb command' cmds
    return
  fi
  local -a plugins custom
  plugins=($OMBD_DIR/plugins/*.zsh(N:t:r))
  custom=($OMBD_CUSTOM/*.zsh(N:t:r))
  case "${words[2]}" in
    list|help|enable|disable) _values 'plugin' $plugins $custom ;;
    edit|remove) (( ${#custom} )) && _values 'custom plugin' $custom ;;
  esac
}
compdef _ombd_omb omb oh-my-bd

# --- cdc / recent ---
_ombd_cdc() {
  if (( CURRENT == 2 )); then
    local -a sub; sub=('add:bookmark a directory' 'rm:remove a bookmark' 'ls:list bookmarks'
                       'clean:drop missing directories' 'help:show help')
    _alternative 'bookmarks:bookmark:_ombd_cdc_names' 'commands:command:((${sub}))'
    return
  fi
  case "${words[2]}" in
    rm|remove) (( CURRENT == 3 )) && _ombd_cdc_names ;;
    add) (( CURRENT == 3 )) && _message 'bookmark name (default: folder name)'
         (( CURRENT == 4 )) && _path_files -/ ;;
  esac
}
compdef _ombd_cdc cdc

# --- note ---
_ombd_note() {
  if (( CURRENT == 2 )); then
    local -a sub; sub=(
      'task:add a task' 'ctx:add context' 'bug:log a bug' 'idea:record an idea'
      'dec:record a decision' 'code:save a snippet' 'done:mark task done'
      'reopen:reopen a task' 'wip:show open tasks' 'rm:remove entry' 'open:open in editor'
      'clear:reset notes' 'help:show help')
    _describe -t commands 'note command' sub
    return
  fi
  case "${words[2]}" in
    done|rm|reopen)
      local f="$(_omb_note_file)"; local -a ids
      [[ -f "$f" ]] && ids=(${(f)"$(sed -nE 's/^- (\[x\] )?\[([0-9]+)\] \[[^]]*\] (.*)$/\2:\3/p' "$f")"})
      _describe -t notes 'note' ids ;;
  esac
}
compdef _ombd_note note

# --- git shortcuts ---
_ombd_switch() { (( CURRENT == 2 )) && _ombd_branches; }
compdef _ombd_switch switch

_ombd_branch() {
  if (( CURRENT == 2 )); then
    local -a sub; sub=('ls:list branches' 'new:create branch' 'rm:delete branch'
                       'rename:rename current branch' 'track:set upstream' 'help:show help')
    _describe -t commands 'branch command' sub
  elif [[ "${words[2]}" == (rm|delete) ]]; then
    _ombd_local_branches
  elif [[ "${words[2]}" == track ]]; then
    local -a r; r=(${(f)"$(git remote 2>/dev/null)"}); _describe -t remotes remote r
  fi
}
compdef _ombd_branch branch

_ombd_repo() {
  local -a sub; sub=('root:jump to git root' 'open:open in browser' 'name:print owner/repo'
                     'main:print default branch' 'url:print web URL' 'pr:open PR page'
                     'issues:open issues' 'help:show help')
  (( CURRENT == 2 )) && _describe -t commands 'repo command' sub
}
compdef _ombd_repo repo

_ombd_browse() {
  local -a sub; sub=('pr:open PR page' 'issues:issues' 'actions:CI runs' 'releases:releases' 'file:open a file')
  if (( CURRENT == 2 )); then _describe -t commands 'page' sub
  elif [[ "${words[2]}" == file ]]; then _files; fi
}
compdef _ombd_browse browse

_ombd_unstash() {
  local -a s; s=(${(f)"$(git stash list --format='%gd:%s' 2>/dev/null)"})
  s=(${s//\{/\\\{}); s=(${s//\}/\\\}})
  (( CURRENT == 2 )) && _describe -t stashes 'stash' s
}
compdef _ombd_unstash unstash

_ombd_release() { (( CURRENT == 2 )) && _values 'bump' patch minor major; }
compdef _ombd_release release

_ombd_gitfiles() {
  local -a f; f=(${(f)"$(git status --porcelain 2>/dev/null | cut -c4- | sed 's/.* -> //')"})
  _describe -t files 'changed file' f
}
compdef _ombd_gitfiles discard add

# --- docker ---
_ombd_context() {
  if (( CURRENT == 2 )); then
    local -a sub; sub=('ls:list contexts' 'use:switch context' 'help:show help')
    _describe -t commands 'context command' sub
  elif [[ "${words[2]}" == use ]]; then
    local -a c; c=(${(f)"$(command docker context ls --format '{{.Name}}' 2>/dev/null)"})
    _describe -t contexts 'context' c
  fi
}
(( $+functions[context] )) && compdef _ombd_context context ctx

_ombd_containers() {
  local -a c; c=(${(f)"$(command docker ps --format '{{.Names}}' 2>/dev/null)"})
  _describe -t containers 'container' c
}
(( $+functions[dsh] )) && compdef _ombd_containers dsh dlogs

_ombd_services() {
  local -a s; s=(${(f)"$(docker compose config --services 2>/dev/null)"})
  (( CURRENT == 2 )) && _describe -t services 'service' s
}
(( $+functions[dcexec] )) && compdef _ombd_services dcexec dcl

# --- misc ---
_ombd_killport() {
  local -a p; p=(${(f)"$(lsof -nP -iTCP -sTCP:LISTEN 2>/dev/null |
    awk 'NR>1 { n = split($9, a, ":"); print a[n] ":" $1 " (pid " $2 ")" }' | sort -un)"})
  _describe -t ports 'listening port' p
}
compdef _ombd_killport kill-port

_ombd_autoenv() { local -a s; s=(allow deny reload unload help); _values 'autoenv' $s; }
(( $+functions[autoenv] )) && compdef _ombd_autoenv autoenv

compdef _files extract
compdef _directories mkcd
