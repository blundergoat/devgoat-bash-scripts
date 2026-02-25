#!/usr/bin/env bash

set -uo pipefail

# Script to lint all shell scripts in the repository with bash -n and shellcheck

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

Runs bash -n (syntax check) and shellcheck on all .sh scripts tracked by git.
Reports pass/fail counters. Exits non-zero if any script fails.

OPTIONS:
    -h, --help      Show this help message
    --fix           Apply shellcheck auto-fixes (requires shellcheck >= 0.9.0)
    --syntax-only   Run bash -n only, skip shellcheck

EXAMPLES:
    $0                  # Lint all scripts
    $0 --fix            # Lint and auto-fix where possible
    $0 --syntax-only    # Syntax check only
EOF
}

# Default values
REPO_ROOT="$(git -C "$(dirname "$0")" rev-parse --show-toplevel 2>/dev/null || (cd "$(dirname "$0")/../.." && pwd))"
FIX_MODE=false
SYNTAX_ONLY=false

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -h|--help)
            show_help
            exit 0
            ;;
        --fix)
            FIX_MODE=true
            shift
            ;;
        --syntax-only)
            SYNTAX_ONLY=true
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

# Collect scripts via git ls-files
cd "$REPO_ROOT" || exit 1

SCRIPTS=()
while IFS= read -r file; do
    SCRIPTS+=("$file")
done < <(git ls-files '*.sh' 2>/dev/null)

if [[ ${#SCRIPTS[@]} -eq 0 ]]; then
    info "No .sh scripts found in repository"
    exit 0
fi

info "Found ${#SCRIPTS[@]} shell scripts"
echo ""

# Counters
syntax_pass=0
syntax_fail=0
sc_pass=0
sc_fail=0
sc_skip=0

HAS_SHELLCHECK=false
if command -v shellcheck &>/dev/null; then
    HAS_SHELLCHECK=true
    sc_version=$(shellcheck --version 2>/dev/null | grep "^version:" | awk '{print $2}')
    info "shellcheck version: ${sc_version:-unknown}"
elif [[ "$SYNTAX_ONLY" != true ]]; then
    warn "shellcheck not found — running syntax checks only"
    warn "Install: https://github.com/koalaman/shellcheck#installing"
    SYNTAX_ONLY=true
fi

echo ""

for file in "${SCRIPTS[@]}"; do
    # bash -n syntax check
    syntax_output=$(bash -n "$file" 2>&1)
    syntax_exit=$?

    if [[ $syntax_exit -eq 0 ]]; then
        syntax_pass=$((syntax_pass + 1))
    else
        syntax_fail=$((syntax_fail + 1))
        echo -e "\033[31mFAIL\033[0m [syntax] $file"
        echo "$syntax_output" | while IFS= read -r line; do
            echo "       $line"
        done
        continue
    fi

    # Run shellcheck if not syntax-only mode
    if [[ "$SYNTAX_ONLY" == true ]]; then
        sc_skip=$((sc_skip + 1))
        echo -e "\033[32mPASS\033[0m [syntax] $file"
        continue
    fi

    if [[ "$HAS_SHELLCHECK" == true ]]; then
        # Exclude SC1091 (can't follow dynamic source) — expected for _common.sh patterns
        sc_args=("--exclude=SC1091")
        if [[ "$FIX_MODE" == true ]]; then
            sc_args+=("--format=diff")
        fi

        sc_output=$(shellcheck "${sc_args[@]}" "$file" 2>&1)
        sc_exit=$?

        if [[ $sc_exit -eq 0 ]]; then
            sc_pass=$((sc_pass + 1))
            echo -e "\033[32mPASS\033[0m $file"
        else
            if [[ "$FIX_MODE" == true && -n "$sc_output" ]]; then
                echo "$sc_output" | git apply 2>/dev/null
                apply_exit=$?
                if [[ $apply_exit -eq 0 ]]; then
                    sc_pass=$((sc_pass + 1))
                    echo -e "\033[33mFIXED\033[0m $file"
                else
                    sc_fail=$((sc_fail + 1))
                    echo -e "\033[31mFAIL\033[0m [shellcheck] $file"
                    shellcheck "$file" 2>&1 | head -20 | while IFS= read -r line; do
                        echo "       $line"
                    done
                fi
            else
                sc_fail=$((sc_fail + 1))
                echo -e "\033[31mFAIL\033[0m [shellcheck] $file"
                echo "$sc_output" | head -20 | while IFS= read -r line; do
                    echo "       $line"
                done
            fi
        fi
    fi
done

# Summary
echo ""
total_fail=$((syntax_fail + sc_fail))

if [[ "$SYNTAX_ONLY" == true ]]; then
    info "Syntax: ${syntax_pass} passed, ${syntax_fail} failed (${#SCRIPTS[@]} total)"
else
    info "Syntax: ${syntax_pass} passed, ${syntax_fail} failed"
    info "Shellcheck: ${sc_pass} passed, ${sc_fail} failed"
    info "Total: $((syntax_pass + sc_pass)) passed, ${total_fail} failed (${#SCRIPTS[@]} scripts)"
fi

if [[ $total_fail -gt 0 ]]; then
    exit 1
fi
