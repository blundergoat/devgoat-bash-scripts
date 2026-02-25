#!/usr/bin/env bash
# =============================================================================
# Node.js Install Dependencies - Installs packages from lockfile
# =============================================================================
# Usage: ./lib/stacks/node/dependencies-install.sh
#
# Installs exact dependency versions from the lockfile. Use after cloning,
# switching branches, or when the lockfile changes.
# =============================================================================

set -euo pipefail

source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/../_common.sh"

# ---- CONFIGURATION ----
PROJECT_NAME="${PROJECT_NAME:-my-project}"
NODE_APP_DIR="${NODE_APP_DIR:-$PROJECT_ROOT}"
PACKAGE_MANAGER="${PACKAGE_MANAGER:-npm}"
# ---- END CONFIGURATION ----

# ── Header ──────────────────────────────────────────────────────────
echo ""
echo -e "${BOLD}  ${PROJECT_NAME} - Install Node.js Dependencies${RESET}"
echo -e "  ${DIM}$(printf '─%.0s' {1..44})${RESET}"
echo ""
echo -e "  ${BOLD}Node.js (${PACKAGE_MANAGER})${RESET}"
echo ""

# Check Node.js
if ! command -v node &>/dev/null; then
    step "node"
    fail "not found"
elif ! command -v "$PACKAGE_MANAGER" &>/dev/null; then
    step "$PACKAGE_MANAGER"
    fail "not found"
else
    # Check node_modules exists
    step "node_modules"
    if [[ -d "$NODE_APP_DIR/node_modules" ]]; then
        pass "exists"
    else
        pass "will create"
    fi

    # Install from lockfile
    step "${PACKAGE_MANAGER} install"
    case "$PACKAGE_MANAGER" in
        npm)
            install_output=$(npm ci --prefix "$NODE_APP_DIR" 2>&1)
            ;;
        yarn)
            install_output=$(yarn --cwd "$NODE_APP_DIR" install --frozen-lockfile 2>&1)
            ;;
        pnpm)
            install_output=$(pnpm --dir "$NODE_APP_DIR" install --frozen-lockfile 2>&1)
            ;;
        *)
            fail "Unknown package manager: $PACKAGE_MANAGER"
            install_output=""
            ;;
    esac
    install_exit=$?

    if [[ $install_exit -eq 0 ]]; then
        pkg_count=$(find "$NODE_APP_DIR/node_modules" -maxdepth 1 -mindepth 1 -type d 2>/dev/null | wc -l)
        pkg_count="${pkg_count//[^0-9]/}"
        pass "${pkg_count} packages"
    else
        fail "${PACKAGE_MANAGER} install failed"
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
