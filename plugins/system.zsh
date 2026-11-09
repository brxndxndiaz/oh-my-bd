# ============================================================
# oh-my-bd — system.zsh — Cross-platform system utilities
# Nothing here replaces a real system command: `paste`, `top`, etc.
# only add behaviour when used interactively and fall through otherwise.
# ============================================================

# --- LS ---
if [[ "$OSTYPE" == darwin* ]]; then
  alias ls='ls -GF'
else
  alias ls='ls --color=auto -F'
fi
alias ll='ls -alFh'
alias la='ls -A'
alias l='ls -CF'

# --- PROCESSES ---
function psg {
  [[ -z "$1" ]] && { print "Usage: psg <pattern>"; return 1; }
  ps aux | head -1
  ps aux | grep -i -- "$1" | grep -v -- "grep -i -- $1"
}

# `top` uses htop/btop when installed; any arguments go to the real top.
function top {
  if (( $# == 0 )); then
    if ombd_has btop; then btop; return; fi
    if ombd_has htop; then htop; return; fi
  fi
  command top "$@"
}

alias cx='chmod +x'

# --- NAVIGATION ---
alias ..='cd ..'
alias ...='cd ../..'
alias ....='cd ../../..'

# --- NETWORK ---
function myip {
  local pub
  pub="$(curl -fsS --max-time 3 https://ifconfig.me 2>/dev/null)"
  print "public : ${pub:-unavailable}"
  if [[ "$OSTYPE" == darwin* ]]; then
    print "local  : $(ipconfig getifaddr en0 2>/dev/null || ipconfig getifaddr en1 2>/dev/null)"
  else
    print "local  : $(hostname -I 2>/dev/null | awk '{print $1}')"
  fi
}

function ports {
  if ombd_has lsof; then lsof -nP -iTCP -sTCP:LISTEN
  elif ombd_has ss; then ss -tulpn
  else netstat -tuln; fi
}

# --- CLIPBOARD ---
# `copy` reads stdin (or file args); `paste` with no args and no pipe prints the
# clipboard, otherwise it behaves exactly like the standard `paste` utility.
function _ombd_clip_copy {
  if [[ "$OSTYPE" == darwin* ]]; then pbcopy
  elif [[ -n "$WAYLAND_DISPLAY" ]] && ombd_has wl-copy; then wl-copy
  elif ombd_has xclip; then xclip -selection clipboard
  elif ombd_has xsel; then xsel --clipboard --input
  elif ombd_has clip.exe; then clip.exe
  else print -u2 "No clipboard tool found (install xclip, xsel or wl-clipboard)"; return 1; fi
}
function _ombd_clip_paste {
  if [[ "$OSTYPE" == darwin* ]]; then pbpaste
  elif [[ -n "$WAYLAND_DISPLAY" ]] && ombd_has wl-paste; then wl-paste --no-newline
  elif ombd_has xclip; then xclip -selection clipboard -o
  elif ombd_has xsel; then xsel --clipboard --output
  elif ombd_has powershell.exe; then powershell.exe -noprofile -command Get-Clipboard
  else print -u2 "No clipboard tool found (install xclip, xsel or wl-clipboard)"; return 1; fi
}
function copy {
  if (( $# )); then cat -- "$@" | _ombd_clip_copy; else _ombd_clip_copy; fi
}
function paste {
  if (( $# == 0 )) && [[ -t 0 ]]; then _ombd_clip_paste; else command paste "$@"; fi
}

# --- MISC ---
[[ "$OSTYPE" == darwin* ]] && alias screenshot='screencapture -i'
alias openurl='ombd_open'
alias c='clear'

function sysinfo {
  print "OS     : $(uname -s) $(uname -r)"
  print "Host   : $(hostname)"
  print "Shell  : $SHELL (zsh $ZSH_VERSION)"
  print "Uptime : $(uptime | sed 's/.*up \([^,]*\),.*/\1/')"
}

function sys {
  if [[ "$1" == help ]]; then
    cat <<'EOF'
sys — System utilities

  ls, ll, la, l    Better ls variants
  psg <pattern>    Search processes
  top              btop/htop if installed, else top
  cx <file>        chmod +x
  .., ..., ....    Go up 1/2/3 directories
  myip             Public + local IP
  ports            Listening ports
  copy [file]      Copy stdin/file to clipboard
  paste            Print clipboard (standard `paste` when given args/stdin)
  sysinfo          System summary
  c                clear
EOF
    return
  fi
  sysinfo
}
