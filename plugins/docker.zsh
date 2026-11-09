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
function _ombd_docker_endpoint {
  local context_name="$1" host="$2"
  if [[ -n "$host" ]]; then
    print -r -- "$host"
  elif [[ -n "$context_name" ]]; then
    DOCKER_HOST= DOCKER_CONTEXT= command docker context inspect --format '{{.Endpoints.docker.Host}}' "$context_name" 2>/dev/null
  elif [[ -n "$DOCKER_CONTEXT" ]]; then
    _ombd_docker_endpoint "$DOCKER_CONTEXT"
  elif [[ -n "$DOCKER_HOST" ]]; then
    print -r -- "$DOCKER_HOST"
  else
    command docker context inspect --format '{{.Endpoints.docker.Host}}' 2>/dev/null
  fi
}

function docker {
  if [[ "${OMBD_DOCKER_GUARD:-1}" == 1 && -t 0 ]]; then
    local -a args=("$@")
    local context_name host endpoint alternate_config
    while (( ${#args} )); do
      case "$args[1]" in
        --context|-c) context_name="$args[2]"; shift 2 args || break ;;
        --host|-H) host="$args[2]"; shift 2 args || break ;;
        --context=*) context_name="${args[1]#*=}"; shift args ;;
        --host=*) host="${args[1]#*=}"; shift args ;;
        -H?*) host="${args[1]#-H}"; host="${host#=}"; shift args ;;
        -c?*) context_name="${args[1]#-c}"; context_name="${context_name#=}"; shift args ;;
        --config) alternate_config=1; shift 2 args || break ;;
        --config=*) alternate_config=1; shift args ;;
        --log-level|-l|--tlscacert|--tlscert|--tlskey) shift 2 args || break ;;
        --help|-h|--version|-v) command docker "$@"; return ;;
        -*) shift args ;;
        *) break ;;
      esac
    done
    case "$args[1]:$args[2]" in
      ps:*|logs:*|images:*|inspect:*|version:*|info:*|stats:*|top:*|events:*|history:*|search:*|context:*|help:*|:|\
      image:ls|image:inspect|image:history|container:ls|container:inspect|container:logs|\
      compose:ps|compose:logs|compose:config|compose:ls|compose:images|compose:top|compose:version) ;;
      *)
        # Alternate config files can select a different context. Ask when the target is unknown.
        if [[ -z "$alternate_config" ]]; then
          endpoint="$(_ombd_docker_endpoint "$context_name" "$host")"
        fi
        if [[ "$endpoint" != (unix://*|npipe://*) ]]; then
          print -u2 -r -- "$(ombd_color yellow '⚠ Docker target') ${endpoint:-${context_name:-unknown}}"
          ombd_confirm "Run 'docker $*' there?" || { print -u2 "Aborted."; return 1; }
        fi ;;
    esac
  fi
  command docker "$@"
}

alias clean-containers='docker container prune -f'
alias clean-images='docker image prune -f'
alias clean-all='docker system prune -a'
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
