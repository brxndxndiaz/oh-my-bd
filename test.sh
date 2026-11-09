#!/bin/sh
# Run the test suite locally, or in a clean Ubuntu container with --docker.
#   ./test.sh            run tests/run.zsh with your local zsh
#   ./test.sh git        only groups matching "git"
#   ./test.sh --docker   run in ubuntu:latest (needs docker)
cd "$(dirname "$0")" || exit 1

if [ "$1" = "--docker" ]; then
  exec docker run --rm -v "$PWD:/src:ro" ubuntu:latest sh -c '
    apt-get update -qq && apt-get install -y -qq zsh dash git fzf >/dev/null &&
    cp -R /src /work && cd /work && zsh tests/run.zsh'
fi

exec zsh tests/run.zsh "$@"
