#!/usr/bin/env bash
# =============================================================================
# Git Checkout — Switch branch in the current repository
# =============================================================================
#
# Switches to the specified branch, creating it if it doesn't exist locally
# but does on the remote.
#
# Usage:
#   ./lib/dev/git-checkout.sh <branch>
#   ./lib/dev/git-checkout.sh -h|--help
#
# =============================================================================

set -euo pipefail

# --- Colors ---
RED='\033[0;31m'
GREEN='\033[0;32m'
DIM='\033[2m'
BOLD='\033[1m'
RESET='\033[0m'

show_help() {
    cat << 'EOF'
Usage: ./lib/dev/git-checkout.sh <branch>

Switch to the specified git branch.

  - If the branch exists locally, checks it out.
  - If only on the remote, creates a local tracking branch.
  - Shows the branch and latest commit after switching.

OPTIONS:
    -h, --help      Show this help message

EXAMPLES:
    ./lib/dev/git-checkout.sh main
    ./lib/dev/git-checkout.sh feature/new-thing
EOF
}

# --- Parse arguments ---
if [[ $# -eq 0 ]]; then
    echo -e "${RED}Error: branch name required${RESET}" >&2
    show_help
    exit 1
fi

case $1 in
    -h|--help) show_help; exit 0 ;;
esac

BRANCH="$1"

# --- Preflight ---
if ! command -v git &>/dev/null; then
    echo -e "${RED}git not found${RESET}" >&2
    exit 1
fi

if ! git rev-parse --is-inside-work-tree &>/dev/null 2>&1; then
    echo -e "${RED}Not a git repository${RESET}" >&2
    exit 1
fi

echo ""
current=$(git branch --show-current 2>/dev/null || echo "(detached)")
echo -e "  ${DIM}Current branch:${RESET} ${current}"

# --- Checkout ---
if git show-ref --verify --quiet "refs/heads/${BRANCH}" 2>/dev/null; then
    # Local branch exists
    echo -e "  ${DIM}Switching to local branch${RESET} ${BOLD}${BRANCH}${RESET}"
    git checkout "${BRANCH}"
elif git show-ref --verify --quiet "refs/remotes/origin/${BRANCH}" 2>/dev/null; then
    # Remote branch exists — create local tracking branch
    echo -e "  ${DIM}Creating local branch from${RESET} origin/${BRANCH}"
    git checkout -b "${BRANCH}" "origin/${BRANCH}"
else
    echo -e "${RED}Branch '${BRANCH}' not found locally or on origin${RESET}" >&2
    echo ""
    echo -e "  ${DIM}Available local branches:${RESET}"
    git branch --format='    %(refname:short)' | head -10
    echo ""
    exit 1
fi

# --- Result ---
echo ""
echo -e "  ${GREEN}${BOLD}Switched to ${BRANCH}${RESET}"
echo -e "  ${DIM}$(git log --oneline -1)${RESET}"
echo ""
