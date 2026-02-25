#!/usr/bin/env bash
# =============================================================================
# PHP Initial Setup - Installs PHP dependencies for local development
# =============================================================================
# Usage: ./lib/stacks/php/setup.sh
#
# Sets up the PHP side of a project: checks prerequisites, copies .env,
# and runs composer install.
#
# Prerequisites:
#   - PHP 8.2+
#   - Composer
# =============================================================================

set -euo pipefail

source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/../_common.sh"

# ---- CONFIGURATION ----
PROJECT_NAME="${PROJECT_NAME:-my-project}"
QUALITY_CHECK_CMD="${QUALITY_CHECK_CMD:-composer preflight}"
START_CMD="${START_CMD:-docker compose up --build}"
# ---- END CONFIGURATION ----

REPO_ROOT="$PROJECT_ROOT"

# ── Prerequisite checks ────────────────────────────────────────────
header "${PROJECT_NAME} - PHP Setup"

echo -e "  ${BOLD}Checking prerequisites${RESET}"
echo ""

step "PHP 8.2+"
if command -v php &>/dev/null; then
    php_version=$(php -r 'echo PHP_MAJOR_VERSION . "." . PHP_MINOR_VERSION;')
    php_major=$(php -r 'echo PHP_MAJOR_VERSION;')
    php_minor=$(php -r 'echo PHP_MINOR_VERSION;')
    if [[ "$php_major" -gt 8 ]] || { [[ "$php_major" -eq 8 ]] && [[ "$php_minor" -ge 2 ]]; }; then
        pass "v${php_version}"
    else
        fail "found v${php_version}, need 8.2+"
    fi
else
    fail "not found"
fi

step "Composer"
if command -v composer &>/dev/null; then
    composer_version=$(composer --version 2>/dev/null | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -1)
    pass "v${composer_version}"
else
    fail "not found - install from https://getcomposer.org"
fi

if [[ $ERRORS -gt 0 ]]; then
    echo ""
    echo -e "  ${RED}${BOLD}Cannot continue - ${ERRORS} prerequisite(s) missing${RESET}"
    echo ""
    exit 1
fi

# ── Environment file ───────────────────────────────────────────────
section "Setting up environment"

step "Copy .env.example → .env"
if [[ -f "$REPO_ROOT/.env" ]]; then
    pass "already exists"
else
    cp "$REPO_ROOT/.env.example" "$REPO_ROOT/.env"
    pass "created"
fi

# ── PHP dependencies ───────────────────────────────────────────────
section "Installing PHP dependencies"

step "composer install"
cd "$REPO_ROOT"
if composer install 2>&1 | tail -1; then
    pass
else
    fail "composer install failed"
fi

# ── Summary ────────────────────────────────────────────────────────
echo ""
divider

if [[ $ERRORS -eq 0 ]]; then
    echo ""
    echo -e "  ${GREEN}${BOLD}Setup complete!${RESET}"
    echo ""
    echo -e "  ${DIM}Next steps:${RESET}"
    echo -e "    ${ARROW} Run quality checks:     ${BOLD}${QUALITY_CHECK_CMD}${RESET}"
    echo -e "    ${ARROW} Start full stack:        ${BOLD}${START_CMD}${RESET}"
    echo ""
else
    echo ""
    echo -e "  ${RED}${BOLD}Setup finished with ${ERRORS} error(s)${RESET}"
    echo ""
    exit 1
fi
