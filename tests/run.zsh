#!/usr/bin/env zsh
# ============================================================
# oh-my-bd test suite — run with: zsh tests/run.zsh [filter]
# Every test runs against a throwaway $HOME; nothing touches yours.
# ============================================================

emulate -L zsh
setopt pipefail
REPO="${0:A:h:h}"
FILTER="${1:-}"
typeset -i PASS=0 FAIL=0
typeset -a FAILED
typeset out f pair load br src omb base bad_tsv

T_ROOT="$(mktemp -d "${TMPDIR:-/tmp}/omb-test.XXXXXX")"
trap 'rm -rf "$T_ROOT"' EXIT

# --- harness -------------------------------------------------
ok()   { (( PASS++ )); print -r -- "  ✓ $1"; }
bad()  { (( FAIL++ )); FAILED+=("$CURRENT: $1"); print -r -- "  ✗ $1"; [[ -n "$2" ]] && print -r -- "$2" | sed 's/^/      /'; }
eq()   { [[ "$2" == "$3" ]] && ok "$1" || bad "$1" "expected: [$3]"$'\n'"got:      [$2]"; }
has()  { [[ "$2" == *"$3"* ]] && ok "$1" || bad "$1" "expected to contain: [$3]"$'\n'"got: [$2]"; }
hasnt(){ [[ "$2" != *"$3"* ]] && ok "$1" || bad "$1" "should not contain: [$3]"$'\n'"got: [$2]"; }
yes()  { local d="$1"; shift; "$@" >/dev/null 2>&1 && ok "$d" || bad "$d"; }
no()   { local d="$1"; shift; "$@" >/dev/null 2>&1 && bad "$d" || ok "$d"; }

# Fresh sandbox per test group.
sandbox() {
  export HOME="$T_ROOT/$1/home"
  export XDG_CONFIG_HOME="$HOME/.config"
  export OMBD_DIR="$REPO" OMBD_CONFIG_DIR="$HOME/.config/oh-my-bd" OMBD_CUSTOM="$HOME/.config/oh-my-bd/plugins"
  export OMBD_SKIP_CHECK=1 OMBD_SILENT=1 NO_COLOR=1 GIT_CONFIG_NOSYSTEM=1
  export GIT_AUTHOR_NAME=t GIT_AUTHOR_EMAIL=t@t GIT_COMMITTER_NAME=t GIT_COMMITTER_EMAIL=t@t
  unset ZDOTDIR CDC_DIR
  mkdir -p "$HOME" "$T_ROOT/$1/work"
  cd "$T_ROOT/$1/work"
}

# Run zsh code with oh-my-bd loaded (non-interactive unless -i).
omb_zsh() {
  local flags=-fc
  [[ "$1" == -i ]] && { flags=-fic; shift; }
  zsh $flags "source \$OMBD_DIR/lib/core.zsh; $1" 2>&1
}

# A repo with an upstream that has main + feature.
make_repos() {
  git init -q -b main up && git -C up commit -q --allow-empty -m init
  git -C up branch feature
  git clone -q up wk 2>/dev/null && cd wk
}

group() {
  CURRENT="$1"
  [[ -n "$FILTER" && "$1" != *$FILTER* ]] && return 1
  print -r -- ""; print -r -- "── $1"
}

# ============================================================
if group syntax; then

  for f in "$REPO"/lib/*.zsh "$REPO"/plugins/*.zsh "$REPO"/bin/oh-my-bd "$REPO"/tests/*.zsh "$REPO"/config.example.zsh; do
    yes "zsh -n ${f#$REPO/}" zsh -n "$f"
  done
  yes "install.sh parses in dash" dash -n "$REPO/install.sh"
  yes "install.sh parses in sh" sh -n "$REPO/install.sh"
  command -v fish >/dev/null && yes "oh-my-bd.fish parses" fish -n "$REPO/oh-my-bd.fish"
  local bad_tsv; bad_tsv="$(grep -v '^#' "$REPO/lib/commands.tsv" | awk -F'\t' 'NF != 3')"
  eq "commands.tsv rows all have 3 columns" "$bad_tsv" ""
fi

# ============================================================
if group core; then
  sandbox core
  
  out="$(omb_zsh -i 'true')"
  eq "interactive load prints nothing" "$out" ""
  out="$(omb_zsh 'true')"
  eq "non-interactive load prints nothing" "$out" ""
  out="$(omb_zsh 'print -r -- "${+p} ${+f} ${+builtin} ${+disabled} ${+plugin_file}"')"
  eq "no loader variables leak" "$out" "0 0 0 0 0"
  out="$(zsh -fc 'plugins=(git z); source $OMBD_DIR/lib/core.zsh; print -r -- $plugins')"
  eq "oh-my-zsh \$plugins is untouched" "$out" "git z"

  mkdir -p "$OMBD_CUSTOM"; print 'function my_custom_cmd { print hi-custom }' > "$OMBD_CUSTOM/mine.zsh"
  out="$(omb_zsh 'my_custom_cmd')"
  eq "custom plugins load" "$out" "hi-custom"

  mkdir -p "$OMBD_CONFIG_DIR"; print 'OMBD_DISABLED_PLUGINS=(notes mine)' > "$OMBD_CONFIG_DIR/config.zsh"
  out="$(omb_zsh 'print -r -- ${+functions[note]} ${+functions[my_custom_cmd]} ${+functions[cdc]}')"
  eq "disabled plugins are skipped" "$out" "0 0 1"
  rm -f "$OMBD_CONFIG_DIR/config.zsh"

  out="$(omb_zsh -i 'whence -w omb')"
  eq "omb is a function (palette) in interactive shells" "$out" "omb: function"
  out="$(omb_zsh 'omb version')"
  has "omb <cmd> forwards to the CLI" "$out" "oh-my-bd $(<$REPO/VERSION)"

  out="$(omb_zsh 'whence -w sync')"
  hasnt "sync is not shadowed" "$out" "function"
  out="$(omb_zsh 'print -l a b > x; print -l 1 2 > y; paste x y')"
  eq "paste with args is the real paste" "$out" $'a\t1\nb\t2'
fi

# ============================================================
if group utils; then
  sandbox utils
  
  git init -q r && cd r
  for pair in \
    "git@github.com:me/proj.git|https://github.com/me/proj" \
    "https://github.com/me/proj.git|https://github.com/me/proj" \
    "ssh://git@gitlab.com:2222/grp/proj.git|https://gitlab.com/grp/proj" \
    "ssh://git@github.com/me/proj|https://github.com/me/proj" \
    "https://user:token@github.com/me/proj.git|https://github.com/me/proj"; do
    git remote remove origin 2>/dev/null; git remote add origin "${pair%%|*}"
    out="$(zsh -fc 'source $OMBD_DIR/lib/utils.zsh; ombd_remote_web_url')"
    eq "web url for ${pair%%|*}" "$out" "${pair#*|}"
  done
  out="$(zsh -fc 'source $OMBD_DIR/lib/utils.zsh; print -l a b c | ombd_pick x' </dev/null)"
  eq "ombd_pick without a terminal returns nothing" "$out" ""
  out="$(zsh -fc 'source $OMBD_DIR/lib/utils.zsh; ombd_confirm "q?" && print y || print n' </dev/null)"
  eq "ombd_confirm defaults to no without a terminal" "$out" "n"
fi

# ============================================================
if group autoenv; then
  sandbox autoenv
  
  mkdir -p proj/sub && cd proj
  cat > .env <<'EOF'
# comment
export FOO=bar
URL=http://x/#frag   # trailing comment
Q="a \"quoted\" # not a comment"
S='single = val'
EQ=abc==
PATH=/evil
GIT_SSH_COMMAND=evil
LD_PRELOAD=/evil.so
EOF
  load='source $OMBD_DIR/lib/utils.zsh; source $OMBD_DIR/plugins/autoenv.zsh'
  out="$(zsh -fc "$load; ombd_autoenv_load .env; print -r \"\${FOO-unset}\"" </dev/null 2>&1)"
  eq "untrusted .env is not loaded without a terminal" "$out" "unset"

  out="$(zsh -fc "$load; _ombd_autoenv_trust .env; ombd_autoenv_load .env 2>/dev/null
    for k in FOO URL Q S EQ; do print -r \"\$k=\${(P)k}\"; done
    print -r \"PATH=\${PATH:0:5} GSC=\${GIT_SSH_COMMAND-unset} LD=\${LD_PRELOAD-unset}\"")"
  has "export prefix" "$out" "FOO=bar"
  has "# inside value kept, trailing comment dropped" "$out" "URL=http://x/#frag"$'\n'
  has "double quotes + escapes" "$out" 'Q=a "quoted" # not a comment'
  has "single quotes" "$out" "S=single = val"
  has "= in value" "$out" "EQ=abc=="
  hasnt "PATH is never set" "$out" "PATH=/evil"
  has "GIT_* and LD_* are blocked" "$out" "GSC=unset LD=unset"

  out="$(zsh -fc "$load; FOO=orig; cd sub; cd ..; print -r \"in:\$FOO\"; cd /; print -r \"out:\$FOO URL:\${URL-unset}\"" 2>/dev/null)"
  has "loaded on cd" "$out" "in:bar"
  has "restored on leaving" "$out" "out:orig URL:unset"

  mkdir -p nested sibling
  print -rl -- FOO=child FOO=last CHILD=child > nested/.env
  out="$(zsh -fc "$load; FOO=orig; autoenv allow 2>/dev/null
    _ombd_autoenv_trust nested/.env
    cd nested; print -r -- child:\$FOO:\$CHILD
    cd ../sibling; print -r -- parent:\$FOO:\${CHILD-unset}
    cd /; print -r -- outside:\$FOO:\${parameters[FOO]}:\${URL-unset}" 2>/dev/null)"
  eq "nested zsh restores parent and original export state" "$out" $'child:last:child\nparent:bar:unset\noutside:orig:scalar:unset'
  if command -v fish >/dev/null; then
    out="$(fish --no-config -c '
      set -gu FOO orig
      source "$OMBD_DIR/oh-my-bd.fish"
      cd nested; echo child:$FOO:$CHILD
      cd ../sibling; echo parent:$FOO:(count $CHILD)
      cd /; echo outside:$FOO:(set -qgx FOO; echo $status):(count $URL)
    ')"
    eq "nested Fish restores parent and original export state" "$out" $'child:last:child\nparent:bar:0\noutside:orig:1:0'
  fi

  print 'NEW=1' >> .env
  out="$(zsh -fc "$load; ombd_autoenv_load .env; print -r \"\${NEW-unset}\"" </dev/null 2>/dev/null)"
  eq "edited .env needs re-approval" "$out" "unset"
fi

# ============================================================
if group git; then
  sandbox git
  
  make_repos
  out="$(omb_zsh 'ombd_git_branch_refs')"
  hasnt "branch list has no bare 'origin'" $'\n'"$out"$'\n' $'\norigin\n'
  has "remote-only branch is listed" "$out" "origin/feature"
  hasnt "origin/main hidden when main exists locally" "$out" "origin/main"

  out="$(omb_zsh '_ombd_git_switch_to origin/feature >/dev/null 2>&1; git branch --show-current; git rev-parse --abbrev-ref @{u}')"
  eq "picking origin/feature tracks it as 'feature'" "$out" $'feature\norigin/feature'
  no "no branch literally named origin/feature" git show-ref --verify --quiet refs/heads/origin/feature
  git switch -q main

  print a > a.txt; print b > b.txt; git add .; git commit -qm files
  print changed > a.txt; print changed > b.txt
  omb_zsh 'discard a.txt' >/dev/null
  eq "discard <file> restores only that file" "$(<a.txt) $(<b.txt)" "a changed"
  omb_zsh 'discard' </dev/null >/dev/null
  eq "discard (all) refuses without confirmation" "$(<b.txt)" "changed"
  OMBD_ASSUME_YES=1 omb_zsh 'discard' >/dev/null
  eq "discard (all) works when confirmed" "$(<b.txt)" "b"

  print c > c.txt; omb_zsh 'commit add c' >/dev/null
  eq "commit auto-stages and commits" "$(git log -1 --format=%s)" "add c"
  omb_zsh 'undo' >/dev/null
  eq "undo keeps changes staged" "$(git diff --cached --name-only)" "c.txt"
  git commit -qm c

  git tag -a v1.2.3 -m x
  OMBD_ASSUME_YES=1 omb_zsh 'release minor' >/dev/null
  eq "release minor bumps tag" "$(git tag --list 'v*' --sort=-version:refname | head -1)" "v1.3.0"

  out="$(omb_zsh 'repo main')"
  eq "default branch detection" "$out" "main"
  out="$(cd / && omb_zsh 'log' 2>&1)"
  eq "log outside a repo doesn't run git" "$out" "Not a git repository"

  git -C ../up branch -q gone-soon && git fetch -q && git switch -q -c gone-soon --track origin/gone-soon && git switch -q main
  git -C ../up branch -q -D gone-soon
  OMBD_ASSUME_YES=1 omb_zsh 'prune' </dev/null >/dev/null
  no "prune deletes branches whose upstream is gone (confirmed)" git show-ref --verify --quiet refs/heads/gone-soon

  mkdir picker-sub
  touch 'literal -> file' 'with space.txt' ':(exclude)literal'
  out="$(omb_zsh 'cd picker-sub; changed')"
  has "changed preserves arrows in filenames" "$out" 'literal -> file'
  has "changed prints paths with spaces" "$out" "with space.txt"
  omb_zsh 'cd picker-sub; ombd_pick() { cat; }; add -i' >/dev/null
  out="$(git diff --cached --name-only)"
  has "stage picker stages a filename containing pathspec syntax" "$out" ':(exclude)literal'
  has "stage picker stages the exact filename with an arrow" "$out" 'literal -> file'

fi

# ============================================================
if group cdc; then
  sandbox cdc
  
  mkdir -p TeamA 'with space' 'a.b' && local base="$PWD"
  out="$(omb_zsh 'cdc add teama TeamA; cdc add sp "with space"; cdc add dot a.b; cdc add x.y TeamA')"
  has "add" "$out" "Added: teama"
  out="$(omb_zsh 'cdc teama && pwd')"
  eq "jump to dir ending in A" "$out" "$base/TeamA"
  out="$(omb_zsh 'cdc sp && pwd')"
  eq "jump to dir with space" "$out" "$base/with space"
  out="$(omb_zsh 'cdc xzy' 2>&1)"
  has "regex chars in names don't fuzzy-match (x.y vs xzy)" "$out" "Unknown project"
  omb_zsh 'cdc teama' >/dev/null
  eq "most recently used goes last" "$(tail -1 ~/.cdc_dirs)" "teama|$base/TeamA"
  out="$(omb_zsh 'cdc add teama with\ space')"
  has "re-adding updates" "$out" "Updated: teama"
  eq "no duplicate entries" "$(grep -c '^teama|' ~/.cdc_dirs)" "1"
  omb_zsh 'cdc rm sp' >/dev/null
  no "rm removes" grep -q '^sp|' ~/.cdc_dirs
  rmdir a.b; out="$(omb_zsh 'cdc clean')"
  has "clean drops missing dirs" "$out" "dot"
  (cd TeamA && omb_zsh 'cdc add' >/dev/null)
  yes "cdc add with no args bookmarks cwd by folder name" grep -q "^TeamA|$base/TeamA$" ~/.cdc_dirs
fi

# ============================================================
if group notes; then
  sandbox notes
  
  omb_zsh 'note help' >/dev/null
  no "note help does not create notes.md" test -e notes.md
  omb_zsh 'note task first; note bug a bug; note task second; note idea shiny' >/dev/null
  out="$(awk '/^## Tasks/{s=1;next} /^## /{s=0} s && NF' notes.md)"
  has "tasks land in Tasks, in order" "$out" $'] first\n'
  has "second task after first" "$out" "] second"
  has "bugs land in Bugs" "$(awk '/^## Bugs/{s=1;next} /^## /{s=0} s && NF' notes.md)" "a bug"
  omb_zsh 'note done 1' >/dev/null
  yes "done marks the entry" grep -q '^- \[x\] \[1\] ' notes.md
  out="$(omb_zsh 'note wip')"
  hasnt "wip hides done tasks" "$out" "first"
  has "wip shows open tasks" "$out" "second"
  hasnt "wip shows only tasks" "$out" "a bug"
  omb_zsh 'note rm 2' >/dev/null
  no "rm removes by id" grep -q 'a bug' notes.md
  omb_zsh 'note task third' >/dev/null
  yes "ids keep increasing after removal" grep -q '^- \[5\] .* third' notes.md
  git init -q . && mkdir -p deep/er && (cd deep/er && omb_zsh 'note ctx from subdir' >/dev/null)
  yes "notes go to the git root from subdirectories" grep -q 'from subdir' notes.md
fi

# ============================================================
if group cli; then
  sandbox cli
  omb="$REPO/bin/oh-my-bd"
  out="$($omb version)"; eq "version" "$out" "oh-my-bd $(<$REPO/VERSION)"
  yes "help" $omb help
  yes "list" $omb list
  out="$($omb list git)"; has "list git" "$out" "switch"
  no "list unknown fails" $omb list nope
  out="$($omb search stash)"; has "search" "$out" "unstash"
  out="$($omb search tre)"; hasnt "search output has no stray ]" "$out" "]"
  yes "cheatsheet" $omb cheatsheet
  no "unknown command exits non-zero" $omb definitely-not
  $omb disable docker >/dev/null
  yes "disable writes config" grep -q 'OMBD_DISABLED_PLUGINS=(docker)' "$OMBD_CONFIG_DIR/config.zsh"
  $omb enable docker >/dev/null
  yes "enable removes it" grep -q 'OMBD_DISABLED_PLUGINS=()' "$OMBD_CONFIG_DIR/config.zsh"
  $omb add myplug </dev/null >/dev/null
  yes "add creates custom plugin" test -f "$OMBD_CUSTOM/myplug.zsh"
  out="$($omb list)"; has "custom plugins are listed" "$out" "myplug"
  OMBD_ASSUME_YES=1 $omb remove myplug >/dev/null
  no "remove deletes it" test -f "$OMBD_CUSTOM/myplug.zsh"
fi

# ============================================================
if group update; then
  sandbox update
  git init -q -b main upstream
  mkdir upstream/lib
  cp "$REPO/lib/utils.zsh" upstream/lib/
  print 1 > upstream/VERSION
  git -C upstream add .
  git -C upstream commit -qm initial
  git clone -q upstream installed
  export OMBD_DIR="$PWD/installed"
  omb="$REPO/bin/oh-my-bd"

  yes "no-op update succeeds" "$omb" update
  print 2 > upstream/VERSION
  git -C upstream commit -qam upgrade
  print local > installed/VERSION
  no "dirty update refuses even with assume yes" env OMBD_ASSUME_YES=1 "$omb" update
  eq "dirty file is preserved" "$(<installed/VERSION)" local
  eq "no stash was created" "$(git -C installed stash list)" ""
  git -C installed restore VERSION
  yes "clean install fast-forwards" "$omb" update
  eq "fast-forward installs the new version" "$(<installed/VERSION)" 2

  git -C installed commit -q --allow-empty -m local-only
  local_head="$(git -C installed rev-parse HEAD)"
  no "local-ahead install refuses update" "$omb" update
  git -C upstream commit -q --allow-empty -m remote-only
  no "divergent install refuses update" "$omb" update
  eq "divergence preserves local HEAD" "$(git -C installed rev-parse HEAD)" "$local_head"
  out="$("$omb" update --auto 2>&1)"
  no "auto mode refuses a divergent install" "$omb" update --auto
  eq "auto mode refuses silently" "$out" ""
  git -C installed switch -q --detach
  no "detached install refuses update" "$omb" update
  eq "detached install preserves HEAD" "$(git -C installed rev-parse HEAD)" "$local_head"
fi

# ============================================================
if group zshrc; then
  sandbox zshrc
  
  cat > ~/.zshrc <<'EOF'
export EDITOR=vim
export PATH="$HOME/.local/bin:$PATH"

# ============================================================
# oh-my-bd — git shortcuts, docker helpers, notes, CDC & more
# ============================================================
export OMBD_DIR="$HOME/.oh-my-bd"
[[ -f "$OMBD_DIR/lib/core.zsh" ]] && source "$OMBD_DIR/lib/core.zsh"
alias omb="oh-my-bd"
alias keepme=true
EOF
  zsh "$REPO/bin/oh-my-bd" migrate-zshrc >/dev/null
  out="$(<~/.zshrc)"
  hasnt "legacy alias removed" "$out" 'alias omb="oh-my-bd"'
  has "marker block added" "$out" "# >>> oh-my-bd >>>"
  has "user PATH line kept" "$out" 'export PATH="$HOME/.local/bin:$PATH"'
  has "user lines after the block kept" "$out" "alias keepme=true"
  yes "backup written" test -f ~/.zshrc.omb-backup
fi

# ============================================================
if group install; then
  sandbox install
  src="$T_ROOT/install/src"
  # Install from a snapshot of the working tree (includes uncommitted changes).
  mkdir -p "$src" && cp -R "$REPO"/. "$src"/ && rm -rf "$src/.git"
  git -C "$src" init -q -b omb-test && git -C "$src" add -A && git -C "$src" commit -qm snapshot
  br=omb-test
  unset OMBD_DIR
  out="$(OMBD_REPO="$src" OMBD_BRANCH="$br" dash "$REPO/install.sh" --no-deps </dev/null 2>&1)"
  has "dash install finishes" "$out" "Done!"
  yes "cloned" test -f ~/.oh-my-bd/lib/core.zsh
  yes "omb symlink" test -L ~/.local/bin/omb
  eq "one marker block" "$(grep -c '>>> oh-my-bd >>>' ~/.zshrc)" "1"
  OMBD_REPO="$src" OMBD_BRANCH="$br" dash "$REPO/install.sh" --no-deps </dev/null >/dev/null 2>&1
  eq "re-running is idempotent" "$(grep -c '>>> oh-my-bd >>>' ~/.zshrc)" "1"
  out="$(zsh -ic 'whence -w omb; print ok' 2>&1 </dev/null)"
  has "fresh shell loads cleanly" "$out" "omb: function"$'\n'"ok"

  # Unattended update: fast-forwards and signals open shells to reload.
  print 'function from_upstream { print up; }' >> "$src/plugins/qol.zsh"
  git -C "$src" commit -qam upstream
  OMBD_DIR="$HOME/.oh-my-bd" zsh ~/.oh-my-bd/bin/oh-my-bd update --auto
  eq "update --auto fast-forwards" "$(git -C ~/.oh-my-bd rev-parse HEAD)" "$(git -C "$src" rev-parse HEAD)"
  has "update --auto signals an automatic reload" "$(<"$HOME/.config/oh-my-bd/reload")" " auto"
  print '# my local edit' >> ~/.oh-my-bd/plugins/git.zsh
  git -C "$src" commit -q --allow-empty -m upstream2
  no "update --auto refuses when the install has local edits" \
    env OMBD_DIR="$HOME/.oh-my-bd" zsh ~/.oh-my-bd/bin/oh-my-bd update --auto
  yes "local edits are untouched" grep -q '# my local edit' ~/.oh-my-bd/plugins/git.zsh
  git -C ~/.oh-my-bd checkout -q -- plugins/git.zsh

  print 'export KEEP=1' >> ~/.zshrc
  print 'user stuff' > ~/.cdc_dirs
  OMBD_DIR="$HOME/.oh-my-bd" zsh ~/.oh-my-bd/bin/oh-my-bd uninstall </dev/null >/dev/null 2>&1
  yes "uninstall refuses without confirmation" test -d ~/.oh-my-bd
  OMBD_ASSUME_YES=1 OMBD_DIR="$HOME/.oh-my-bd" zsh ~/.oh-my-bd/bin/oh-my-bd uninstall >/dev/null 2>&1
  no "uninstall removes the install dir" test -d ~/.oh-my-bd
  no "uninstall removes the block" grep -q 'oh-my-bd' ~/.zshrc
  yes "uninstall keeps other .zshrc lines" grep -q 'export KEEP=1' ~/.zshrc
  no "uninstall removes omb symlink" test -L ~/.local/bin/omb
fi

# ============================================================
if group docker; then
  sandbox docker
  mkdir -p fakebin
  print -rl -- '#!/bin/sh' 'case "$*" in' \
    '  "context inspect"*) echo "$FAKE_HOST" ;;' '  "context show") echo prod ;;' \
    '  *) echo "ran: $*" ;;' 'esac' > fakebin/docker
  chmod +x fakebin/docker
  load='source $OMBD_DIR/lib/utils.zsh; source $OMBD_DIR/plugins/docker.zsh'
  out="$(PATH="$PWD/fakebin:$PATH" FAKE_HOST=unix:///var/run/docker.sock zsh -fc "$load; _ombd_docker_endpoint")"
  eq "unix socket context resolves to local endpoint" "$out" "unix:///var/run/docker.sock"
  out="$(PATH="$PWD/fakebin:$PATH" FAKE_HOST=ssh://deploy@prod zsh -fc "$load; _ombd_docker_endpoint")"
  eq "SSH context resolves to remote endpoint" "$out" "ssh://deploy@prod"
  out="$(PATH="$PWD/fakebin:$PATH" FAKE_HOST=ssh://deploy@prod zsh -fc "$load; docker ps" </dev/null)"
  eq "wrapper passes through without a terminal" "$out" "ran: ps"
  out="$(PATH="$PWD/fakebin:$PATH" DOCKER_HOST=ssh://direct zsh -fc "$load; _ombd_docker_endpoint")"
  eq "Docker target respects DOCKER_HOST" "$out" "ssh://direct"
  out="$(PATH="$PWD/fakebin:$PATH" DOCKER_HOST=ssh://direct DOCKER_CONTEXT=local FAKE_HOST=unix:///socket zsh -fc "$load; _ombd_docker_endpoint")"
  eq "Docker context overrides environment host" "$out" "unix:///socket"

fi

# ============================================================
if group files; then
  sandbox files
  mkdir -p proj/sub "$HOME/docs/deep" "$HOME/node_modules/x" && print a > proj/sub/here.txt
  print b > "$HOME/docs/deep/lost.md"; print c > "$HOME/node_modules/x/skip.js"; print d > "$HOME/docs/old.md"
  touch -t 202001010000 "$HOME/docs/old.md"
  cd proj
  st="$T_ROOT/files/state"; rm -f "$st"
  out="$(zsh "$REPO/bin/ombd-files" list "$st")"
  has "here: header first" "${out%%$'\n'*}" "HERE"
  has "here: lists relative paths" "$out" $'\nsub/here.txt'
  out="$(zsh "$REPO/bin/ombd-files" next "$st")"
  has "Tab → everywhere" "${out%%$'\n'*}" "EVERYWHERE"
  has "everywhere: finds files under ~ as ~/…" "$out" "~/docs/deep/lost.md"
  hasnt "everywhere: skips node_modules" "$out" "skip.js"
  out="$(zsh "$REPO/bin/ombd-files" next "$st")"
  has "Tab → recently modified" "${out%%$'\n'*}" "RECENTLY MODIFIED"
  has "recent: includes new files" "$out" "~/docs/deep/lost.md"
  hasnt "recent: excludes old files" "$out" "old.md"
  out="$(zsh "$REPO/bin/ombd-files" next "$st")"
  has "Tab wraps back to here" "${out%%$'\n'*}" "HERE"
  out="$(zsh "$REPO/bin/ombd-files" preview "~/docs/deep/lost.md")"
  eq "preview resolves ~/ paths" "$out" "b"
fi

# ============================================================
if group text && command -v rg >/dev/null; then
  sandbox text
  mkdir -p project/sub
  cd project
  print -r -- 'needle in project' > parent.txt
  print -rl -- 'other' 'needle [x] $value' > 'sub/a: b.txt'
  print -r -- 'needle [x] $value' > sub/.env
  out="$(zsh "$REPO/bin/ombd-files" text "$PWD/sub" 'needle [x] $value')"
  has "literal search shows match at line 2" "$out" 'a: b.txt:2: needle [x] $value'
  hasnt "search omits hidden files" "$out" '.env'
  typeset -a local_row
  local_row=("${(@ps:\t:)out}")
  eq "selection retains the full path" "${(Q)local_row[1]}" "$PWD/sub/a: b.txt"
  out="$(zsh "$REPO/bin/ombd-files" text-preview "$local_row[1]" "$local_row[2]")"
  has "preview shows matching line" "$out" 'needle [x] $value'
  eq "current-directory scope stays inside its root" "$(zsh "$REPO/bin/ombd-files" text "$PWD/sub" 'needle in project')" ""
  has "wider scope includes parent files" "$(zsh "$REPO/bin/ombd-files" text "$PWD" 'needle in project')" 'parent.txt:1:'
  eq "empty query leaves the picker empty" "$(zsh "$REPO/bin/ombd-files" text "$PWD" '')" ""
fi

# ============================================================
if group palette; then
  sandbox palette
  out="$(omb_zsh 'OMBD_DISABLED_PLUGINS=(notes); note() { :; }; _ombd_palette_rows')"
  has "palette includes available commands" "$out" 'commit [message]'
  hasnt "palette excludes disabled plugins" "$out" 'note task'
  out="$(omb_zsh 'ff() { :; }; _ombd_palette_rows')"
  has "palette includes available finder command" "$out" 'ff [here|everywhere|recent]'
  hasnt "palette excludes shortcut-only rows" "$out" 'Ctrl+F'
fi

# ============================================================
if group reload; then
  sandbox reload
  mkdir -p proj && print 'FOO=bar' > proj/.env
  out="$(zsh -fic '
    source $OMBD_DIR/lib/core.zsh
    cd proj; _ombd_autoenv_trust .env; ombd_autoenv_load .env 2>/dev/null
    functions[cdc]="print stub"; _ombd_reload_check
    print "idle:$(cdc)"
    zsh $OMBD_DIR/bin/oh-my-bd disable notes >/dev/null
    zsh $OMBD_DIR/bin/oh-my-bd disable autoenv >/dev/null
    _ombd_reload_check
    print "disabled:${+functions[note]}:${+functions[cdc]}:${#chpwd_functions}:${FOO}"
    cd /; cd ~; print "hooks:ok"
    zsh $OMBD_DIR/bin/oh-my-bd enable notes >/dev/null
    zsh $OMBD_DIR/bin/oh-my-bd enable autoenv >/dev/null
    _ombd_reload_check
    print "enabled:${+functions[note]}:${chpwd_functions[*]}"
  ' 2>&1 </dev/null)"
  has "no reload without a signal" "$out" "idle:stub"
  has "disabled plugin's commands are removed live" "$out" "disabled:0:1:"
  has "its hooks are removed too" "$out" "disabled:0:1:0:"
  has "loaded .env survives a reload" "$out" ":0:bar"
  has "no errors from removed hooks" "$out" "hooks:ok"
  has "re-enabled plugin comes back live" "$out" "enabled:1:_ombd_autoenv_chpwd"
  hasnt "reload prints no errors" "$out" "command not found"
fi

# ============================================================
if group completions; then
  sandbox completions
  
  out="$(zsh -fic 'source $OMBD_DIR/lib/core.zsh; print -r -- ${_comps[cdc]} ${_comps[note]} ${_comps[switch]} ${_comps[omb]}' 2>&1 </dev/null)"
  eq "completions registered" "$out" "_ombd_cdc _ombd_note _ombd_switch _ombd_omb"
fi

# ============================================================
print ""
if (( FAIL )); then
  print -r -- "FAILED: $FAIL   passed: $PASS"
  print -rl -- "  - "${^FAILED}
  exit 1
fi
print -r -- "All $PASS checks passed."
