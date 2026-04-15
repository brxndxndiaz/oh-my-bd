#!/usr/bin/env zsh
# ============================================================
# oh-my-bd — Release script
# Usage: ./release.sh [patch|minor|major]
# ============================================================

cd "$(dirname "$0")"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
RESET='\033[0m'

# Get current version
current=$(git describe --tags --abbrev=0 2>/dev/null || echo "0.0.0")
IFS='.' read -r major minor patch <<< "$current"

case "${1:-patch}" in
  major) ((major++)); minor=0; patch=0 ;;
  minor) ((minor++)); patch=0 ;;
  patch) ((patch++)) ;;
  *) echo "Usage: $0 [patch|minor|major]"; exit 1 ;;
esac

new_version="${major}.${minor}.${patch}"
tag="v${new_version}"

echo ""
echo -e "${GREEN}Bumping version: ${current} -> ${new_version}${RESET}"
echo ""

# Run tests first
echo -e "${YELLOW}Running tests...${RESET}"
if ! ./test.sh 2>&1 | grep -q "All checks passed"; then
  echo -e "${RED}Tests failed. Aborting release.${RESET}"
  exit 1
fi

# Amend last commit with release tag
echo -e "${YELLOW}Creating tag ${tag}...${RESET}"
git tag -a "$tag" -m "Release ${tag}" HEAD

echo ""
echo -e "${GREEN}Release ${tag} ready!${RESET}"
echo ""
echo "To push and create release:"
echo "  git push origin ${tag}"
echo "  gh release create ${tag} --title '${tag}' --notes 'Release ${tag}'"
echo ""
