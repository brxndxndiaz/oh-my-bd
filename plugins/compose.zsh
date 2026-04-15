# ============================================================
# oh-my-bd — compose.zsh — Docker Compose shortcuts
# ============================================================

command -v docker >/dev/null 2>&1 || return

alias dcup='docker compose up'
alias dcupd='docker compose up -d'
alias dcdown='docker compose down'
alias dcstop='docker compose stop'
alias dcstart='docker compose start'
alias dcrestart='docker compose restart'
alias dcbuild='docker compose build'
alias dclogs='docker compose logs'
alias dclogsf='docker compose logs -f'
alias dcps='docker compose ps'
alias dcexec='docker compose exec'
alias dcrun='docker compose run --rm'
alias dcrm='docker compose rm'
alias dcpull='docker compose pull'
alias dcconfig='docker compose config'
alias dcln='docker compose logs --tail=100'

dcl() {
  if [[ "$1" == "help" ]]; then
    cat << 'EOF'
dcl — Docker Compose shortcuts

Aliases:
  dcup       docker compose up
  dcupd      docker compose up -d (detached)
  dcdown     docker compose down
  dcstop     docker compose stop
  dcstart    docker compose start
  dcrestart docker compose restart
  dcbuild    docker compose build
  dclogs     docker compose logs
  dclogsf    docker compose logs -f (follow)
  dcp        docker compose ps
  dcexec     docker compose exec
  dcrun      docker compose run --rm
  dcrm       docker compose rm
  dcpull     docker compose pull
  dcconfig   docker compose config
  dcln       docker compose logs (last 100 lines)

Functions:
  dcl help   Show this help
EOF
    return
  fi
  dclogs "$@"
}
