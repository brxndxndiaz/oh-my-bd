# ============================================================
# oh-my-bd — compose.zsh — Docker Compose shortcuts
# ============================================================

ombd_has docker || return 0

alias dcup='docker compose up'
alias dcupd='docker compose up -d'
alias dcdown='docker compose down'
alias dcstop='docker compose stop'
alias dcstart='docker compose start'
alias dcrestart='docker compose restart'
alias dcbuild='docker compose build'
alias dclogs='docker compose logs'
alias dclogsf='docker compose logs -f --tail=200'
alias dcln='docker compose logs --tail=100'
alias dcps='docker compose ps'
alias dcrun='docker compose run --rm'
alias dcrm='docker compose rm'
alias dcpull='docker compose pull'
alias dcconfig='docker compose config'

function _ombd_compose_services { docker compose config --services 2>/dev/null; }

# dcexec [service] [cmd...] — exec into a service (picker, default shell)
function dcexec {
  local svc="$1"
  if [[ -z "$svc" ]]; then
    svc="$(_ombd_compose_services | ombd_pick 'Service:')" || return 0
  else
    shift
  fi
  if (( $# )); then
    docker compose exec "$svc" "$@"
  else
    docker compose exec "$svc" sh -c 'command -v bash >/dev/null && exec bash || exec sh'
  fi
}

function dcl {
  if [[ "$1" == help ]]; then
    cat <<'EOF'
Docker Compose shortcuts

  dcup / dcupd        up / up -d             dcdown     down
  dcstop / dcstart    stop / start           dcrestart  restart
  dcbuild             build                  dcpull     pull
  dclogs / dclogsf    logs / follow          dcln       last 100 lines
  dcps                ps                     dcrm       rm
  dcrun <svc> ...     run --rm               dcconfig   config
  dcexec [svc] [cmd]  exec (picker + shell if omitted)
  dcl [svc]           follow logs (alias of dclogsf)
EOF
    return
  fi
  docker compose logs -f --tail=200 "$@"
}
