#!/usr/bin/env bash

set -euo pipefail

# Script to pull latest changes and restore executable bits on all scripts

# Color functions for output
info() {
    echo -e "\033[32mINFO:\033[0m $1"
}

warn() {
    echo -e "\033[33mWARN:\033[0m $1"
}

err() {
    echo -e "\033[31mERROR:\033[0m $1"
}

show_help() {
    cat << EOF
Usage: $0 [OPTIONS]

Pulls latest changes via git pull --rebase, then runs
make-scripts-executable.sh to restore chmod +x on all .sh files.
Shows a summary of changed files.

OPTIONS:
    -h, --help      Show this help message
    -n, --dry-run   Show what would happen without pulling or modifying

EXAMPLES:
    $0                  # Pull and update
    $0 --dry-run        # Preview changes
EOF
}

# Default values
REPO_ROOT="$(git -C "$(dirname "$0")" rev-parse --show-toplevel 2>/dev/null || (cd "$(dirname "$0")/../.." && pwd))"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DRY_RUN=false

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -h|--help)
            show_help
            exit 0
            ;;
        -n|--dry-run)
            DRY_RUN=true
            shift
            ;;
        -*)
            err "Unknown option: $1"
            show_help
            exit 1
            ;;
        *)
            err "Unexpected argument: $1"
            show_help
            exit 1
            ;;
    esac
done

cd "$REPO_ROOT" || exit 1

# Ensure we're in a git repo
if ! git rev-parse --is-inside-work-tree &>/dev/null; then
    err "Not inside a git repository"
    exit 1
fi

# Check for uncommitted changes
if ! git diff-index --quiet HEAD -- 2>/dev/null; then
    warn "You have uncommitted changes — rebase may fail"
fi

# Record HEAD before pull
BEFORE_SHA=$(git rev-parse HEAD 2>/dev/null)

# Pull latest changes
info "Pulling latest changes..."

if [[ "$DRY_RUN" == true ]]; then
    git fetch --quiet 2>/dev/null || true
    incoming=$(git log --oneline "HEAD..@{u}" 2>/dev/null || true)
    if [[ -n "$incoming" ]]; then
        info "DRY RUN: Would pull the following commits:"
        echo "$incoming" | while IFS= read -r line; do
            echo -e "  \033[36m$line\033[0m"
        done
    else
        info "DRY RUN: Already up to date"
    fi
else
    pull_output=$(git pull --rebase 2>&1)
    pull_exit=$?

    if [[ $pull_exit -ne 0 ]]; then
        err "git pull --rebase failed:"
        echo "$pull_output"
        exit 1
    fi

    echo "$pull_output"
fi

# Show changed files summary
AFTER_SHA=$(git rev-parse HEAD 2>/dev/null)

if [[ "$BEFORE_SHA" != "$AFTER_SHA" && "$DRY_RUN" != true ]]; then
    echo ""
    changed_files=$(git diff --name-only "$BEFORE_SHA" "$AFTER_SHA" 2>/dev/null)
    changed_count=$(echo "$changed_files" | grep -c . || true)
    info "Changed files: $changed_count"
    echo "$changed_files" | while IFS= read -r file; do
        echo -e "  \033[36m$file\033[0m"
    done
fi

# Restore executable bits
echo ""
MAKE_EXEC="$SCRIPT_DIR/make-scripts-executable.sh"

if [[ ! -x "$MAKE_EXEC" ]]; then
    chmod +x "$MAKE_EXEC" 2>/dev/null || true
fi

if [[ -f "$MAKE_EXEC" ]]; then
    if [[ "$DRY_RUN" == true ]]; then
        info "Would run: make-scripts-executable.sh --dry-run"
        bash "$MAKE_EXEC" --dry-run
    else
        info "Restoring executable bits..."
        bash "$MAKE_EXEC"
    fi
else
    warn "make-scripts-executable.sh not found at $MAKE_EXEC"
fi
