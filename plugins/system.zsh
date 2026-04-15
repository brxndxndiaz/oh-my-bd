# ============================================================
# oh-my-bd — system.zsh — Cross-platform system utilities
# ============================================================

# --- LS ALTERNATIVES ---
if [[ "$(uname)" == "Darwin" ]]; then
  alias ls='ls -GF'
else
  alias ls='ls --color=auto -F'
fi

# --- COMMON ALIASES ---
alias ll='ls -alFh'
alias la='ls -A'
alias l='ls -CF'

# --- PROCESS MANAGEMENT ---
alias psg='ps aux | grep -v grep | grep'
alias top='htop 2>/dev/null || top'

# --- FILE PERMISSIONS ---
alias cx='chmod +x'

# --- QUICK NAVIGATION ---
alias ..='cd ..'
alias ...='cd ../..'
alias ....='cd ../../..'
alias ~='cd ~'

# --- IP ADDRESS ---
alias myip='curl -s ifconfig.me 2>/dev/null || hostname -I | awk "{print \$1}"'

# --- COPY/PASTE (cross-platform) ---
if [[ "$(uname)" == "Darwin" ]]; then
  alias copy='pbcopy'
  alias paste='pbpaste'
else
  alias copy='xclip -selection clipboard'
  alias paste='xclip -selection clipboard -o'
fi

# --- SCREENSHOT ---
if [[ "$(uname)" == "Darwin" ]]; then
  alias screenshot='screencapture -i'
fi

# --- OPEN IN BROWSER ---
if [[ "$(uname)" == "Darwin" ]]; then
  alias openurl='open'
elif command -v xdg-open &>/dev/null; then
  alias openurl='xdg-open'
fi

# --- SYSTEM INFO ---
alias sysinfo='echo "OS: $(uname -s)" && echo "Kernel: $(uname -r)" && echo "Shell: $SHELL" && echo "Host: $(hostname)"'

# --- CLEAR ---
alias c='clear'

# --- PORT CHECK ---
alias ports='ss -tulanp 2>/dev/null || netstat -tulanp'

# --- DISCARD CHANGES ---
discard() {
  if [[ -z "$1" ]]; then
    git reset --hard HEAD
  else
    git checkout -- "$@"
  fi
}

# --- SYSTEM HELP ---
sys() {
  if [[ "$1" == "help" ]]; then
    cat << 'EOF'
sys — System utilities

Aliases:
  ls, ll, la, l    Better ls variants
  psg <name>       Grep processes
  top              htop or top
  cx <file>        chmod +x
  .., ..., ....    Quick navigation
  myip             Show IP address
  copy, paste      Clipboard (cross-platform)
  sysinfo          System information
  c                clear
  ports            Show listening ports
  discard [file]   Discard git changes

Functions:
  sys help         Show this help
EOF
    return
  fi
  sysinfo
}
