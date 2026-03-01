#!/usr/bin/env bash
# =============================================================================
# Git Status - Quick overview of the current repo state
# =============================================================================
#
# Shows branch, recent commits, and working tree status at a glance.
# Useful as a dashboard "home screen" script.
#
# Usage:
#   ./lib/workflow/git-status.sh
#   ./lib/workflow/git-status.sh -h|--help
#
# =============================================================================

set -euo pipefail

# --- Colors ---
GREEN='\033[0;32m'
DIM='\033[2m'
BOLD='\033[1m'
RESET='\033[0m'

show_help() {
    cat << 'EOF'
Usage: ./lib/workflow/git-status.sh

Show a quick overview of the current git repository:
  - Current branch and remote tracking info
  - Last 10 commits (one-line)
  - Working tree status (modified, staged, untracked)

OPTIONS:
    -h, --help      Show this help message
EOF
}

while [[ $# -gt 0 ]]; do
    case $1 in
        -h|--help) show_help; exit 0 ;;
        *) echo "Unknown option: $1" >&2; show_help; exit 1 ;;
    esac
done

if ! command -v git &>/dev/null; then
    echo "git not found" >&2
    exit 1
fi

if ! git rev-parse --is-inside-work-tree &>/dev/null 2>&1; then
    echo "Not a git repository" >&2
    exit 1
fi

echo ""
echo -e "${BOLD}  Branch${RESET}"
echo -e "  ${DIM}$(printf '─%.0s' {1..50})${RESET}"
branch=$(git branch --show-current 2>/dev/null || echo "(detached)")
remote=$(git rev-parse --abbrev-ref --symbolic-full-name '@{u}' 2>/dev/null || echo "no upstream")
echo -e "  ${GREEN}${branch}${RESET}  ${DIM}→ ${remote}${RESET}"
echo ""

echo -e "${BOLD}  Recent Commits${RESET}"
echo -e "  ${DIM}$(printf '─%.0s' {1..50})${RESET}"
git log --oneline --decorate -10 2>/dev/null | while IFS= read -r line; do
    echo -e "  ${DIM}${line}${RESET}"
done
echo ""

echo -e "${BOLD}  Working Tree${RESET}"
echo -e "  ${DIM}$(printf '─%.0s' {1..50})${RESET}"
status=$(git status --short 2>/dev/null)
if [[ -z "${status}" ]]; then
    echo -e "  ${GREEN}Clean - nothing to commit${RESET}"
else
    echo "${status}" | while IFS= read -r line; do
        echo "  ${line}"
    done
fi
echo ""
