#!/usr/bin/env bash
# =============================================================================
# Git Change Branch - Safely switch branch in the current repository
# =============================================================================
#
# Stashes uncommitted work, fetches latest remotes, then switches to the
# specified branch. If something goes wrong, run: git stash pop
#
# Usage:
#   ./lib/workflow/git-change-branch.sh <branch>
#   ./lib/workflow/git-change-branch.sh -h|--help
#
# =============================================================================

set -euo pipefail

# --- Colors ---
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
DIM='\033[2m'
BOLD='\033[1m'
RESET='\033[0m'

show_help() {
    cat << 'EOF'
Usage: ./lib/workflow/git-change-branch.sh <branch>

Safely switch to the specified git branch.

Steps:
  1. Stashes any uncommitted changes (git add . && git stash)
  2. Fetches latest from remote (git fetch)
  3. Checks out the target branch
  4. Shows recovery hint if changes were stashed

If the branch exists only on the remote, creates a local tracking branch.

OPTIONS:
    -h, --help      Show this help message

RECOVERY:
    git stash pop   Restore stashed changes after an accidental switch

EXAMPLES:
    ./lib/workflow/git-change-branch.sh main
    ./lib/workflow/git-change-branch.sh feature/new-thing
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

# --- Stash uncommitted changes ---
stashed=false
if [[ -n "$(git status --porcelain 2>/dev/null)" ]]; then
    echo -e "  ${DIM}Stashing uncommitted changes...${RESET}"
    git add .
    git stash
    stashed=true
fi

# --- Fetch latest ---
echo -e "  ${DIM}Fetching latest from remote...${RESET}"
git fetch --quiet

# --- Checkout ---
if git show-ref --verify --quiet "refs/heads/${BRANCH}" 2>/dev/null; then
    # Local branch exists
    echo -e "  ${DIM}Switching to local branch${RESET} ${BOLD}${BRANCH}${RESET}"
    git checkout "${BRANCH}" --quiet
elif git show-ref --verify --quiet "refs/remotes/origin/${BRANCH}" 2>/dev/null; then
    # Remote branch exists - create local tracking branch
    echo -e "  ${DIM}Creating local branch from${RESET} origin/${BRANCH}"
    git checkout -b "${BRANCH}" "origin/${BRANCH}" --quiet
else
    echo -e "${RED}Branch '${BRANCH}' not found locally or on origin${RESET}" >&2
    echo ""
    echo -e "  ${DIM}Available local branches:${RESET}"
    git branch --format='    %(refname:short)' | head -10
    # Unstash if we stashed before failing
    if [[ "$stashed" == true ]]; then
        echo ""
        echo -e "  ${YELLOW}Restoring stashed changes...${RESET}"
        git stash pop --quiet
    fi
    echo ""
    exit 1
fi

# --- Result ---
echo ""
echo -e "  ${GREEN}${BOLD}Switched to ${BRANCH}${RESET}"
echo -e "  ${DIM}$(git log --oneline -1)${RESET}"
if [[ "$stashed" == true ]]; then
    echo -e "  ${YELLOW}Changes were stashed from ${current}.${RESET}"
    echo -e "  ${DIM}Run${RESET} git stash pop ${DIM}to restore them.${RESET}"
fi
echo ""
