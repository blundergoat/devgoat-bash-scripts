#!/usr/bin/env bash
# =============================================================================
# Node.js Initial Setup - Installs Node.js dependencies for local development
# =============================================================================
# Usage: ./lib/stacks/node/setup.sh
#
# Sets up the Node.js side of a project: checks prerequisites, copies .env,
# and installs packages via npm/yarn/pnpm.
#
# Prerequisites:
#   - Node.js 18+
#   - npm, yarn, or pnpm
# =============================================================================

set -euo pipefail

source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/../_common.sh"

# ---- CONFIGURATION ----
PROJECT_NAME="${PROJECT_NAME:-my-project}"
NODE_APP_DIR="${NODE_APP_DIR:-$PROJECT_ROOT}"
PACKAGE_MANAGER="${PACKAGE_MANAGER:-npm}"
QUALITY_CHECK_CMD="${QUALITY_CHECK_CMD:-lib/stacks/node/preflight-checks.sh}"
START_CMD="${START_CMD:-npm run dev}"
# ---- END CONFIGURATION ----

REPO_ROOT="$PROJECT_ROOT"

# ── Package manager helper ────────────────────────────────────────
pm_install() {
    case "$PACKAGE_MANAGER" in
        npm)  npm ci --prefix "$NODE_APP_DIR" ;;
        yarn) yarn --cwd "$NODE_APP_DIR" install --frozen-lockfile ;;
        pnpm) pnpm --dir "$NODE_APP_DIR" install --frozen-lockfile ;;
        *)    fail "Unknown package manager: $PACKAGE_MANAGER"; return 1 ;;
    esac
}

# ── Prerequisite checks ────────────────────────────────────────────
header "${PROJECT_NAME} - Node.js Setup"

echo -e "  ${BOLD}Checking prerequisites${RESET}"
echo ""

step "Node.js 18+"
if command -v node &>/dev/null; then
    node_version=$(node --version 2>/dev/null | sed 's/^v//')
    node_major=$(echo "$node_version" | cut -d. -f1)
    if [[ "$node_major" -ge 18 ]]; then
        pass "v${node_version}"
    else
        fail "found v${node_version}, need 18+"
    fi
else
    fail "not found"
fi

step "${PACKAGE_MANAGER}"
if command -v "$PACKAGE_MANAGER" &>/dev/null; then
    pm_version=$("$PACKAGE_MANAGER" --version 2>/dev/null)
    pass "v${pm_version}"
else
    fail "not found"
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
elif [[ -f "$REPO_ROOT/.env.example" ]]; then
    cp "$REPO_ROOT/.env.example" "$REPO_ROOT/.env"
    pass "created"
else
    skip "no .env.example found"
fi

# ── Install dependencies ──────────────────────────────────────────
section "Installing Node.js dependencies"

step "${PACKAGE_MANAGER} install"
if pm_install 2>&1 | tail -1; then
    pass
else
    fail "${PACKAGE_MANAGER} install failed"
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
    echo -e "    ${ARROW} Start dev server:        ${BOLD}${START_CMD}${RESET}"
    echo ""
else
    echo ""
    echo -e "  ${RED}${BOLD}Setup finished with ${ERRORS} error(s)${RESET}"
    echo ""
    exit 1
fi
