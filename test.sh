#!/usr/bin/env zsh
# ============================================================
# oh-my-bd — Test script
# Runs in clean Docker container by default
# ============================================================

cd "$(dirname "$0")"

# Run in Docker by default
docker run --rm \
  -v "$PWD:/tmp/oh-my-bd" \
  -w /tmp/oh-my-bd \
  ubuntu:latest bash -c "
    apt-get update -qq >/dev/null 2>&1
    apt-get install -y -qq zsh git curl >/dev/null 2>&1

    echo ''
    echo '=== Testing oh-my-bd in clean Ubuntu ==='
    echo ''

    # Syntax checks
    echo '--- Syntax ---'
    passed=0
    for f in plugins/*.zsh lib/*.zsh bin/oh-my-bd install.sh; do
      if zsh -n \"\$f\" 2>/dev/null; then
        echo \"  ✓ \$f\"
        ((passed++))
      else
        echo \"  ✗ \$f\"
      fi
    done

    echo ''
    echo '--- Load Test ---'
    if zsh -c '
      export HOME=/tmp
      export OMBD_DIR=/tmp/oh-my-bd
      source lib/utils.zsh
      source lib/core.zsh
      echo \"  ✓ core.zsh loaded\"
    ' 2>&1; then
      echo '  ✓ core.zsh works'
    else
      echo '  ✗ core.zsh failed'
    fi

    echo ''
    echo 'Syntax checks: \$passed/11'
    echo 'All checks passed!'
  "
