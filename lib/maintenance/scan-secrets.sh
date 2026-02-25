#!/usr/bin/env bash

set -euo pipefail

# Script to scan for accidentally committed secrets in the repository

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
Usage: $0 [OPTIONS] [PATH]

Scans for accidentally committed secrets (AWS keys, private keys, tokens,
passwords). Uses gitleaks if available, falls back to grep-based patterns.

OPTIONS:
    -h, --help      Show this help message
    --staged        Scan only staged files (default, for pre-commit hook use)
    --all           Scan all files tracked by git
    -n, --dry-run   Show what would be scanned without scanning

ARGUMENTS:
    PATH            Scan a specific file or directory

EXAMPLES:
    $0                          # Scan staged files (pre-commit)
    $0 --all                    # Scan entire repo
    $0 lib/aws/                 # Scan specific directory
    $0 --staged                 # Explicitly scan staged files
EOF
}

# Default values
REPO_ROOT="$(git -C "$(dirname "$0")" rev-parse --show-toplevel 2>/dev/null || (cd "$(dirname "$0")/../.." && pwd))"
SCAN_MODE="staged"
TARGET_PATH=""
DRY_RUN=false

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -h|--help)
            show_help
            exit 0
            ;;
        --staged)
            SCAN_MODE="staged"
            shift
            ;;
        --all)
            SCAN_MODE="all"
            shift
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
            TARGET_PATH="$1"
            SCAN_MODE="path"
            shift
            ;;
    esac
done

cd "$REPO_ROOT" || exit 1

# Secret patterns (grep -E extended regex)
SECRET_PATTERNS=(
    # AWS Access Key ID (starts with AKIA)
    'AKIA[0-9A-Z]{16}'
    # AWS Secret Access Key (40 char base64)
    '(?<![A-Za-z0-9/+=])[A-Za-z0-9/+=]{40}(?![A-Za-z0-9/+=])'
    # Private keys
    '-----BEGIN (RSA |EC |DSA |OPENSSH )?PRIVATE KEY-----'
    # Generic high-entropy tokens assigned to variables
    '(password|passwd|secret|token|api_key|apikey|access_key)[\s]*[=:][\s]*["\x27][^\s"'\'']{8,}'
    # GitHub personal access tokens
    'ghp_[A-Za-z0-9]{36}'
    # Generic Bearer tokens
    'Bearer [A-Za-z0-9\-._~+/]+=*'
)

# Build combined pattern
COMBINED_PATTERN=""
for pattern in "${SECRET_PATTERNS[@]}"; do
    if [[ -n "$COMBINED_PATTERN" ]]; then
        COMBINED_PATTERN="${COMBINED_PATTERN}|${pattern}"
    else
        COMBINED_PATTERN="$pattern"
    fi
done

# Collect files to scan
collect_files() {
    case "$SCAN_MODE" in
        staged)
            git diff --cached --name-only --diff-filter=ACMR 2>/dev/null
            ;;
        all)
            git ls-files 2>/dev/null
            ;;
        path)
            if [[ -d "$TARGET_PATH" ]]; then
                git ls-files "$TARGET_PATH" 2>/dev/null
            elif [[ -f "$TARGET_PATH" ]]; then
                echo "$TARGET_PATH"
            else
                err "Path does not exist: $TARGET_PATH"
                exit 1
            fi
            ;;
    esac
}

FILES=()
while IFS= read -r file; do
    [[ -z "$file" ]] && continue
    # Skip binary files and common non-secret files
    case "$file" in
        *.png|*.jpg|*.jpeg|*.gif|*.ico|*.woff|*.woff2|*.ttf|*.eot|*.pdf|*.zip|*.tar*|*.gz)
            continue
            ;;
    esac
    FILES+=("$file")
done < <(collect_files)

if [[ ${#FILES[@]} -eq 0 ]]; then
    info "No files to scan (mode: $SCAN_MODE)"
    exit 0
fi

info "Scanning ${#FILES[@]} files (mode: $SCAN_MODE)"

if [[ "$DRY_RUN" == true ]]; then
    info "DRY RUN: Would scan the following files:"
    for file in "${FILES[@]}"; do
        echo -e "  \033[36m$file\033[0m"
    done
    exit 0
fi

# Try gitleaks first
if command -v gitleaks &>/dev/null; then
    info "Using gitleaks"
    echo ""

    gitleaks_args=("detect" "--source" "$REPO_ROOT" "--no-git" "--verbose")

    case "$SCAN_MODE" in
        staged)
            gitleaks_args=("detect" "--source" "$REPO_ROOT" "--staged" "--verbose")
            ;;
    esac

    gitleaks_output=$(gitleaks "${gitleaks_args[@]}" 2>&1)
    gitleaks_exit=$?

    if [[ $gitleaks_exit -eq 0 ]]; then
        info "No secrets found"
        exit 0
    else
        err "Potential secrets detected!"
        echo ""
        echo "$gitleaks_output"
        exit 1
    fi
fi

# Fallback: grep-based scan
info "Using grep-based patterns (install gitleaks for better detection)"
echo ""

findings=0

for file in "${FILES[@]}"; do
    [[ ! -f "$file" ]] && continue

    # Use grep -P for Perl-compatible regex, fall back to -E
    match_output=""
    if grep -PnH "$COMBINED_PATTERN" "$file" 2>/dev/null; then
        match_output=$(grep -PnH "$COMBINED_PATTERN" "$file" 2>/dev/null)
    elif grep -EnH "(AKIA[0-9A-Z]{16}|-----BEGIN.*PRIVATE KEY-----|ghp_[A-Za-z0-9]{36})" "$file" 2>/dev/null; then
        match_output=$(grep -EnH "(AKIA[0-9A-Z]{16}|-----BEGIN.*PRIVATE KEY-----|ghp_[A-Za-z0-9]{36})" "$file" 2>/dev/null)
    fi

    if [[ -n "$match_output" ]]; then
        echo "$match_output" | while IFS= read -r line; do
            echo -e "\033[31mFOUND:\033[0m $line"
            findings=$((findings + 1))
        done
        findings=$((findings + 1))
    fi
done

echo ""

if [[ $findings -gt 0 ]]; then
    err "Potential secrets detected in $findings file(s). Review before committing."
    exit 1
else
    info "No secrets found"
fi
