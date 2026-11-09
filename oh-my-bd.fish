# ============================================================
# oh-my-bd — Fish shell integration (a small subset of the zsh toolkit)
# Sourced from ~/.config/fish/config.fish by the installer.
# ============================================================

if set -q OMB_FISH_INIT
    return 0
end
set -g OMB_FISH_INIT 1
set -q OMBD_DIR; or set -gx OMBD_DIR "$HOME/.oh-my-bd"
set -q OMBD_CONFIG_DIR; or set -gx OMBD_CONFIG_DIR (set -q XDG_CONFIG_HOME; and echo $XDG_CONFIG_HOME; or echo $HOME/.config)/oh-my-bd

# --- FZF ---
if type -q fzf
    fzf --fish 2>/dev/null | source
    if type -q fd
        set -gx FZF_DEFAULT_COMMAND 'fd --type f --hidden --follow --exclude .git'
        set -gx FZF_CTRL_T_COMMAND $FZF_DEFAULT_COMMAND
        set -gx FZF_ALT_C_COMMAND 'fd --type d --hidden --follow --exclude .git'
    end
    set -q FZF_DEFAULT_OPTS; or set -gx FZF_DEFAULT_OPTS '--height 40% --layout=reverse --border'
end

# --- Aliases ---
alias ll 'ls -alFh'
alias la 'ls -A'
alias l 'ls -CF'
alias gs 'git status -sb'
alias ga 'git add'
alias gc 'git commit'
alias gp 'git push'
alias gl 'git log --oneline --graph --decorate'
alias dcup 'docker compose up'
alias dcupd 'docker compose up -d'
alias dcdown 'docker compose down'
alias omb "$OMBD_DIR/bin/oh-my-bd"

# --- CDC bookmarks (shares ~/.cdc_dirs with zsh) ---
set -q CDC_DIR; or set -gx CDC_DIR "$HOME/.cdc_dirs"

function cdc --description 'Jump to a project bookmark'
    set -l cmd $argv[1]
    switch "$cmd"
        case ''
            test -s "$CDC_DIR"; or begin; echo "No bookmarks. Add: cdc add <name> [path]"; return; end
            if type -q fzf
                set -l pick (awk -F'|' '{p=$0; sub(/^[^|]*\|/,"",p); print $1 "\t" p}' "$CDC_DIR" | fzf --delimiter='\t' --prompt='Jump to: ')
                test -n "$pick"; and cdc (string split -m1 \t -- $pick)[1]
            else
                awk -F'|' '{print "  " $1 "  →  " substr($0, length($1) + 2)}' "$CDC_DIR"
            end
        case add
            set -l name $argv[2]
            set -l dir $argv[3]
            test -n "$name"; or set name (basename $PWD)
            test -n "$dir"; or set dir $PWD
            set dir (realpath $dir)
            awk -F'|' -v n="$name" 'NF && $1 != n' "$CDC_DIR" 2>/dev/null >"$CDC_DIR.tmp"
            echo "$name|$dir" >>"$CDC_DIR.tmp"
            mv -f "$CDC_DIR.tmp" "$CDC_DIR"
            echo "Added: $name -> $dir"
        case rm
            test -n "$argv[2]"; or begin; echo "Usage: cdc rm <name>"; return 1; end
            awk -F'|' -v n="$argv[2]" 'NF && $1 != n' "$CDC_DIR" >"$CDC_DIR.tmp"; and mv -f "$CDC_DIR.tmp" "$CDC_DIR"
            echo "Removed: $argv[2]"
        case ls
            awk -F'|' '{print "  " $1 "  →  " substr($0, length($1) + 2)}' "$CDC_DIR" 2>/dev/null
        case '*'
            set -l target (awk -F'|' -v n="$cmd" '$1 == n {print substr($0, length($1) + 2); exit}' "$CDC_DIR" 2>/dev/null)
            if test -n "$target" -a -d "$target"
                cd "$target"
            else
                echo "Unknown project: $cmd"
                return 1
            end
    end
end
complete -c cdc -f -a '(awk -F"|" "{print \$1}" $CDC_DIR 2>/dev/null) add rm ls'

# --- Autoenv: load ./.env only if trusted (same trust file as zsh) ---
set -g __omb_autoenv_blocked PATH HOME PWD OLDPWD SHELL USER IFS argv ZDOTDIR ENV BASH_ENV PROMPT_COMMAND \
    PYTHONPATH PYTHONSTARTUP NODE_OPTIONS PERL5OPT RUBYOPT EDITOR VISUAL PAGER SSH_AUTH_SOCK OMBD_DIR

function __omb_sha
    if type -q sha256sum
        sha256sum -- $argv[1] | string split -f1 ' '
    else if type -q shasum
        shasum -a 256 -- $argv[1] | string split -f1 ' '
    else
        cksum -- $argv[1] | string split -f1,2 ' ' | string join -
    end
end

function __omb_autoenv_unload
    for key in $__omb_autoenv_keys
        set -l saved __omb_autoenv_saved_$key
        if contains -- $key $__omb_autoenv_exported
            set -gx $key $$saved
        else if set -qg $saved
            set -gu $key $$saved
        else
            set -eg $key
        end
        set -eg $saved
    end
    set -e __omb_autoenv_keys __omb_autoenv_exported __omb_autoenv_dir
end

function __omb_autoenv_save
    if set -qg $argv[1]
        set -g __omb_autoenv_saved_$argv[1] $$argv[1]
        if set -qgx $argv[1]
            set -ga __omb_autoenv_exported $argv[1]
        end
    end
    set -ga __omb_autoenv_keys $argv[1]
end

function __omb_autoenv_load
    set -l file (realpath -- "$argv[1]/.env"); or return 1
    set -l trust "$OMBD_CONFIG_DIR/autoenv-trusted"
    if not grep -qxF -- (__omb_sha "$file")" $file" "$trust" 2>/dev/null
        if test "$argv[2]" = warn
            echo "[oh-my-bd] untrusted .env — trust it from zsh with: autoenv allow" >&2
        end
        return 1
    end
    __omb_autoenv_unload
    for line in (string trim < "$file")
        string match -qr '^(#|$)' -- $line; and continue
        set line (string replace -r '^export\s+' '' -- $line)
        set -l kv (string split -m1 '=' -- $line)
        test (count $kv) -eq 2; or continue
        set -l key (string trim -- $kv[1])
        string match -qr '^[A-Za-z_][A-Za-z0-9_]*$' -- $key; or continue
        if contains -- $key $__omb_autoenv_blocked; or string match -qr '^(LD_|DYLD_|GIT_|__omb_autoenv_)' -- $key
            continue
        end
        set -l val (string trim -- $kv[2])
        if string match -qr '^".*"$' -- $val; or string match -qr "^'.*'\$" -- $val
            set val (string sub -s 2 -e -1 -- $val)
        else
            set val (string replace -r '\s+#.*$' '' -- $val)
        end
        if not contains -- $key $__omb_autoenv_keys
            __omb_autoenv_save "$key"
        end
        set -gx $key "$val"
    end
    set -g __omb_autoenv_dir "$argv[1]"
end

function __omb_autoenv --on-variable PWD
    if test "$OMBD_AUTOENV" = 0
        __omb_autoenv_unload
        return
    end
    set -l dir (pwd -P)
    set -l left
    if set -q __omb_autoenv_dir
        set -l active_prefix (string escape --style=regex -- "$__omb_autoenv_dir/")
        if not string match -qr -- "^$active_prefix" "$dir/"
            __omb_autoenv_unload
            set left 1
        end
    end
    if test -f "$dir/.env"; and test "$dir" != "$__omb_autoenv_dir"
        __omb_autoenv_load "$dir" warn
    end
    if set -q left[1]; and not set -q __omb_autoenv_dir
        while test "$dir" != /
            set dir (dirname -- "$dir")
            if test -f "$dir/.env"; and __omb_autoenv_load "$dir" quiet
                break
            end
        end
    end
end
__omb_autoenv
