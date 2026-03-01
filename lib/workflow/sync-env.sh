#!/usr/bin/env bash
# =============================================================================
# Sync Env - Copy .env.example files to .env where missing
# =============================================================================
# Usage: ./scripts/sync-env.sh [--force] [--diff]
#
# Finds all .env.example files in configured directories and creates
# corresponding .env files if they don't already exist. Useful after cloning
# a repo or adding new services.
#
# =============================================================================

set -euo pipefail

# ---- CONFIGURATION ----
# Customize these variables for your project, or set them as environment variables.
PROJECT_ROOT="${PROJECT_ROOT:-$(git -C "$(dirname "$0")" rev-parse --show-toplevel 2>/dev/null || (cd "$(dirname "$0")/.." && pwd))}"
# Space-separated list of directories to scan (relative to PROJECT_ROOT)
SCAN_DIRS="${SCAN_DIRS:-.}"
# Name of the example env file
ENV_EXAMPLE_NAME="${ENV_EXAMPLE_NAME:-.env.example}"
# ---- END CONFIGURATION ----

# ── Colors ──────────────────────────────────────────────────────────
RED='\033[0;31m'
GREEN='\033[0;32m'
# shellcheck disable=SC2034
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
DIM='\033[2m'
BOLD='\033[1m'
RESET='\033[0m'

PASS="${GREEN}✔${RESET}"
ARROW="${BLUE}▸${RESET}"

show_help() {
    cat << EOF
Usage: $0 [OPTIONS]

Finds ${ENV_EXAMPLE_NAME} files and creates corresponding .env files
where missing.

OPTIONS:
    -h, --help      Show this help message
    --force         Overwrite existing .env files with ${ENV_EXAMPLE_NAME}
    --diff          Show diff between existing .env and ${ENV_EXAMPLE_NAME}

EXAMPLES:
    $0                  # Create missing .env files
    $0 --diff           # Show differences
    $0 --force          # Overwrite all .env files
EOF
}

# Default values
FORCE=false
SHOW_DIFF=false

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -h|--help)
            show_help
            exit 0
            ;;
        --force)
            FORCE=true
            shift
            ;;
        --diff)
            SHOW_DIFF=true
            shift
            ;;
        -*)
            echo -e "${RED}Unknown option: $1${RESET}"
            show_help
            exit 1
            ;;
        *)
            echo -e "${RED}Unexpected argument: $1${RESET}"
            show_help
            exit 1
            ;;
    esac
done

cd "$PROJECT_ROOT" || exit 1

echo ""
echo -e "${BOLD}  Sync Environment Files${RESET}"
echo -e "  ${DIM}$(printf '─%.0s' {1..44})${RESET}"
echo ""

# Find all .env.example files
EXAMPLES=()
for scan_dir in $SCAN_DIRS; do
    while IFS= read -r -d '' file; do
        EXAMPLES+=("$file")
    done < <(find "$PROJECT_ROOT/$scan_dir" -name "$ENV_EXAMPLE_NAME" -type f -print0 2>/dev/null || true)
done

if [[ ${#EXAMPLES[@]} -eq 0 ]]; then
    echo -e "  ${DIM}No ${ENV_EXAMPLE_NAME} files found${RESET}"
    echo ""
    exit 0
fi

echo -e "  Found ${#EXAMPLES[@]} ${ENV_EXAMPLE_NAME} file(s)"
echo ""

created=0
skipped=0
overwritten=0

for example in "${EXAMPLES[@]}"; do
    dir=$(dirname "$example")
    env_file="$dir/.env"
    rel_path="${example#"$PROJECT_ROOT"/}"

    if [[ "$SHOW_DIFF" == true && -f "$env_file" ]]; then
        rel_env="${env_file#"$PROJECT_ROOT"/}"
        echo -e "  ${ARROW} ${BOLD}${rel_env}${RESET} vs ${DIM}${rel_path}${RESET}"
        diff_output=$(diff --color=always "$env_file" "$example" 2>/dev/null || true)
        if [[ -n "$diff_output" ]]; then
            echo "$diff_output" | while IFS= read -r line; do
                echo "    $line"
            done
        else
            echo -e "    ${DIM}(identical)${RESET}"
        fi
        echo ""
        continue
    fi

    if [[ -f "$env_file" && "$FORCE" != true ]]; then
        rel_env="${env_file#"$PROJECT_ROOT"/}"
        echo -e "  ${PASS} ${DIM}${rel_env} already exists${RESET}"
        skipped=$((skipped + 1))
    else
        cp "$example" "$env_file"
        rel_env="${env_file#"$PROJECT_ROOT"/}"
        if [[ "$FORCE" == true && -f "$env_file" ]]; then
            echo -e "  ${PASS} ${BOLD}Overwritten:${RESET} ${rel_env}"
            overwritten=$((overwritten + 1))
        else
            echo -e "  ${PASS} ${BOLD}Created:${RESET} ${rel_env}"
            created=$((created + 1))
        fi
    fi
done

# Summary
echo ""
echo -e "  ${DIM}$(printf '─%.0s' {1..44})${RESET}"
echo ""

if [[ "$SHOW_DIFF" == true ]]; then
    echo -e "  ${DIM}Diff complete${RESET}"
else
    parts=()
    [[ $created -gt 0 ]] && parts+=("${created} created")
    [[ $overwritten -gt 0 ]] && parts+=("${overwritten} overwritten")
    [[ $skipped -gt 0 ]] && parts+=("${skipped} already existed")
    summary=$(IFS=", "; echo "${parts[*]}")
    echo -e "  ${GREEN}${BOLD}Done.${RESET} ${DIM}${summary}${RESET}"
fi
echo ""
