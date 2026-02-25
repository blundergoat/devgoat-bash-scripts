#!/usr/bin/env bash
# =============================================================================
# PHP Install Dependencies - Installs packages from composer.lock
# =============================================================================
# Usage: ./lib/stacks/php/dependencies-install.sh
#
# Installs exact versions from composer.lock.
# Use this after cloning, switching branches, or when lock files change.
# =============================================================================

set -euo pipefail

source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/../_common.sh"

# ---- CONFIGURATION ----
PROJECT_NAME="${PROJECT_NAME:-my-project}"
# ---- END CONFIGURATION ----

REPO_ROOT="$PROJECT_ROOT"

# ── Header ──────────────────────────────────────────────────────────
echo ""
echo -e "${BOLD}  ${PROJECT_NAME} - Install PHP Dependencies${RESET}"
echo -e "  ${DIM}$(printf '─%.0s' {1..44})${RESET}"
echo ""
echo -e "  ${BOLD}PHP (Composer)${RESET}"
echo ""

if ! command -v composer &>/dev/null; then
    step "composer"
    fail "not found - install from https://getcomposer.org"
else
    step "composer install"
    install_output=$(cd "$REPO_ROOT" && composer install 2>&1)
    install_exit=$?
    if [[ $install_exit -eq 0 ]]; then
        pkg_count=$(cd "$REPO_ROOT" && composer show 2>/dev/null | wc -l)
        pass "${pkg_count} packages"
    else
        fail "composer install failed"
        echo "$install_output" | tail -5 | while IFS= read -r line; do
            echo -e "    ${DIM}${line}${RESET}"
        done
    fi
fi

# ── Summary ─────────────────────────────────────────────────────────
echo ""
divider
echo ""

if [[ $ERRORS -eq 0 ]]; then
    echo -e "  ${GREEN}${BOLD}All dependencies installed${RESET}"
    echo ""
else
    echo -e "  ${RED}${BOLD}${ERRORS} error(s) during install${RESET}"
    echo ""
    exit 1
fi
