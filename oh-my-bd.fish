# ============================================================
# oh-my-bd — Fish shell integration
# This file should be sourced by Fish shell config
# ============================================================

# Check if we're in Fish
if not set -q OMB_FISH_INIT
    set -gx OMB_FISH_INIT 1

    # FZF integration
    if type -q fzf
        fzf --fish | source
        set -gx FZF_DEFAULT_COMMAND 'fd --type f --hidden --follow --exclude .git'
        set -gx FZF_CTRL_T_COMMAND '$FZF_DEFAULT_COMMAND'
        set -gx FZF_ALT_C_COMMAND 'fd --type d --hidden --follow --exclude .git'
        set -gx FZF_DEFAULT_OPTS '--height 40% --layout=reverse --border --ansi'
    end

    # Aliases for common tools
    alias ll 'ls -alFh'
    alias la 'ls -A'
    alias l 'ls -CF'
    alias gs 'git status -s'
    alias ga 'git add'
    alias gc 'git commit'
    alias gp 'git push'
    alias gl 'git log --oneline --graph'

    # Docker Compose shortcuts
    alias dcup 'docker compose up'
    alias dcupd 'docker compose up -d'
    alias dcdown 'docker compose down'

    # CDC directory bookmarks
    function cdc
        set -l cmd $argv[1]
        set -l cdc_file "$HOME/.cdc_dirs"

        if test -z "$cmd"
            if test -f "$cdc_file"
                cat "$cdc_file"
            end
        else if test "$cmd" = "add"
            if test (count $argv) -ge 3
                echo "$argv[2]|$argv[3]" >> "$cdc_file"
                echo "Added: $argv[2] -> $argv[3]"
            else
                echo "Usage: cdc add <name> <path>"
            end
        else if test "$cmd" = "rm"
            if test (count $argv) -ge 2
                set -l name "$argv[2]"
                set -l tmp_file (mktemp)
                grep -v "^$name|" "$cdc_file" > "$tmp_file"
                mv "$tmp_file" "$cdc_file"
                echo "Removed: $name"
            end
        else
            if test -f "$cdc_file"
                set -l target (grep "^$cmd|" "$cdc_file" | cut -d'|' -f2)
                if test -n "$target"
                    cd "$target"
                else
                    echo "Bookmark not found: $cmd"
                end
            end
        end
    end

    # Auto-load .env on cd (using Fish event)
    function __omb_autoenv --on-variable PWD
        if test -f .env
            while read -l line
                if not string match -q '#*' "$line"
                    and not test -z "$line"
                    set -l key (string split '=' $line)[1]
                    set -l value (string split '=' $line)[2]
                    # Remove quotes
                    set -l value (string replace -a '"' '' $value)
                    set -l value (string replace -a "'" '' $value)
                    export $key=$value
                end
            end < .env
        end
    end

    # Load .env on shell start too
    if test -f .env
        while read -l line
            if not string match -q '#*' "$line"
                and not test -z "$line"
                set -l key (string split '=' $line)[1]
                set -l value (string split '=' $line)[2]
                set -l value (string replace -a '"' '' $value)
                set -l value (string replace -a "'" '' $value)
                export $key=$value
            end
        end < .env
    end

end
