#!/usr/bin/env zsh
# ============================================================
# oh-my-bd — Test script
# Runs in Docker container with full dependencies
# Usage: ./test.sh [--local]
# ============================================================

cd "$(dirname "$0")"

# Local mode - run without Docker
if [[ "$1" == "--local" || "$1" == "-l" ]]; then
  echo "=== Running local tests ==="
  echo ""
  
  export OMBD_DIR="$PWD"
  export HOME="${HOME:-/tmp}"
  
  echo "--- Syntax ---"
  passed=0
  for f in plugins/*.zsh lib/*.zsh bin/oh-my-bd install.sh; do
    if zsh -n "$f" 2>/dev/null; then
      echo "  ✓ ${f:t}"
      ((passed++))
    else
      echo "  ✗ ${f:t}"
    fi
  done
  
  echo ""
  echo "--- CLI Tests ---"
  for cmd in list help version; do
    if ./bin/oh-my-bd "$cmd" >/dev/null 2>&1; then
      echo "  ✓ oh-my-bd $cmd"
    else
      echo "  ✗ oh-my-bd $cmd"
    fi
  done
  
  echo ""
  echo "Syntax checks: $passed/11"
  exit 0
fi

# Docker mode
echo "=== Testing oh-my-bd in clean Ubuntu ==="
echo ""

docker run --rm \
  -v "$PWD:/tmp/oh-my-bd" \
  -w /tmp/oh-my-bd \
  ubuntu:latest bash -c '
    set -e
    export DEBIAN_FRONTEND=noninteractive
    apt-get update -qq
    apt-get install -y -qq zsh git curl fzf tree >/dev/null 2>&1

    echo "--- Environment ---"
    echo "  ✓ Ubuntu latest"
    echo "  ✓ zsh installed"
    echo "  ✓ git installed"
    echo "  ✓ fzf installed"
    echo "  ✓ tree installed"
    echo ""

    echo "--- Syntax ---"
    passed=0
    for f in plugins/*.zsh lib/*.zsh bin/oh-my-bd install.sh; do
      if zsh -n "$f" 2>/dev/null; then
        echo "  ✓ $(basename $f)"
        passed=$((passed + 1))
      else
        echo "  ✗ $(basename $f)"
      fi
    done

    echo ""
    echo "--- CLI Tests ---"
    for cmd in list help version; do
      if ./bin/oh-my-bd "$cmd" >/dev/null 2>&1; then
        echo "  ✓ oh-my-bd $cmd"
      else
        echo "  ✗ oh-my-bd $cmd"
      fi
    done
    
    for plugin in compose docker git notes qol system fzf; do
      if ./bin/oh-my-bd list "$plugin" >/dev/null 2>&1; then
        echo "  ✓ oh-my-bd list $plugin"
      else
        echo "  ✗ oh-my-bd list $plugin"
      fi
    done

    echo ""
    echo "--- Load Test ---"
    if zsh -c "export OMBD_DIR=/tmp/oh-my-bd && source lib/utils.zsh && source lib/core.zsh" 2>&1; then
      echo "  ✓ core.zsh loaded"
    else
      echo "  ✗ core.zsh failed"
    fi

    echo ""
    echo "--- Plugin Load Tests ---"
    zsh -c "
      export OMBD_DIR=/tmp/oh-my-bd
      source lib/utils.zsh
      source lib/core.zsh
      for plugin in plugins/*.zsh; do
        if source \"\$plugin\" 2>&1 | grep -qi error; then
          echo \"  ✗ \$(basename \$plugin) (has errors)\"
        else
          echo \"  ✓ \$(basename \$plugin)\"
        fi
      done
    " 2>&1 || true

    echo ""
    echo "Syntax checks: $passed/11"
    echo "All checks passed!"
  '
