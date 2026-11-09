# ============================================================
# oh-my-bd — docker.zsh — Docker context helpers + remote-context guard
# ============================================================

ombd_has docker || return 0

function context {
  case "${1:-}" in
    help|-h)
      cat <<'EOF'
context — Docker context manager (alias: ctx)

  context              Show current context
  context ls           List contexts
  context use [name]   Switch context (picker if no name)
EOF
      ;;
    "") command docker context show ;;
    use)
      local name="$2"
      if [[ -z "$name" ]]; then
        name="$(command docker context ls --format '{{.Name}}' | ombd_pick 'Context:')" || return 0
      fi
      command docker context use "$name" ;;
    *) command docker context "$@" ;;
  esac
}
alias ctx=context

# --- Remote-context guard -------------------------------------
# Asks before running a *mutating* docker command when the current context
# points somewhere other than this machine (e.g. a production host).
# Read-only commands (ps, logs, images, inspect, …) never prompt.
# Disable with OMBD_DOCKER_GUARD=0.
function _ombd_docker_is_remote {
  local host
  host="$(command docker context inspect --format '{{.Endpoints.docker.Host}}' 2>/dev/null)"
  [[ -n "$host" && "$host" != unix://* && "$host" != npipe://* ]]
}

function docker {
  if [[ "${OMBD_DOCKER_GUARD:-1}" == 1 && -t 0 ]]; then
    local sub="$1"
    [[ "$sub" == compose ]] && sub="compose:${2:-}"
    case "$sub" in
      ps|logs|images|image|inspect|version|info|stats|top|events|history|search|context|help|--help|-h|""|\
      compose:ps|compose:logs|compose:config|compose:ls|compose:images|compose:top|compose:version) ;;
      *)
        if _ombd_docker_is_remote; then
          print -u2 -- "$(ombd_color yellow '⚠ Docker context') '$(command docker context show)' is $(ombd_color bold remote)."
          ombd_confirm "Run 'docker $*' there?" || { print -u2 "Aborted."; return 1; }
        fi ;;
    esac
  fi
  command docker "$@"
}

alias clean-containers='command docker container prune -f'
alias clean-images='command docker image prune -f'
alias clean-all='command docker system prune -a'
alias dps='command docker ps --format "table {{.Names}}\t{{.Image}}\t{{.Status}}\t{{.Ports}}"'
alias dpsa='command docker ps -a --format "table {{.Names}}\t{{.Image}}\t{{.Status}}"'

# dsh [container] — shell into a running container (picker if omitted)
function dsh {
  local c="$1"
  if [[ -z "$c" ]]; then
    c="$(command docker ps --format '{{.Names}}\t{{.Image}}\t{{.Status}}' |
      ombd_pick 'Shell into:' --delimiter='\t')" || return 0
    c="${c%%$'\t'*}"
  fi
  docker exec -it "$c" sh -c 'command -v bash >/dev/null && exec bash || exec sh'
}

# dlogs [container] — follow logs (picker if omitted)
function dlogs {
  local c="$1"
  if [[ -z "$c" ]]; then
    c="$(command docker ps --format '{{.Names}}\t{{.Image}}' | ombd_pick 'Logs:' --delimiter='\t')" || return 0
    c="${c%%$'\t'*}"
  fi
  command docker logs -f --tail=200 "$c"
}

ombd_has lazydocker && alias lz='lazydocker'
