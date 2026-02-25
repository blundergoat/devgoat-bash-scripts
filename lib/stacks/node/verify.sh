#!/usr/bin/env bash
# =============================================================================
# Node.js Verify Setup - Checks that Node.js tools and config are installed
# =============================================================================
# Usage: ./lib/stacks/node/verify.sh
#
# Run after setup.sh (or any time) to confirm the Node.js development environment
# is complete and ready. Checks system tools, project files, node_modules,
# and dev tooling (eslint, jest/vitest, tsc).
# =============================================================================

set -uo pipefail

source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/../_common.sh"

# ---- CONFIGURATION ----
PROJECT_NAME="${PROJECT_NAME:-my-project}"
NODE_APP_DIR="${NODE_APP_DIR:-$PROJECT_ROOT}"
PACKAGE_MANAGER="${PACKAGE_MANAGER:-npm}"
# Env vars to verify exist in .env (space-separated)
REQUIRED_ENV_VARS="${REQUIRED_ENV_VARS:-}"
# Expected binaries in node_modules/.bin (space-separated)
NODE_BIN_CHECKS="${NODE_BIN_CHECKS:-}"
# ---- END CONFIGURATION ----

REPO_ROOT="$PROJECT_ROOT"

# ═════════════════════════════════════════════════════════════════════
header "${PROJECT_NAME} - Node.js Verification"

# ── System Tools ────────────────────────────────────────────────────
section "System tools"

step "Node.js 18+"
if command -v node &>/dev/null; then
    node_version=$(node --version 2>/dev/null | sed 's/^v//')
    node_major=$(echo "$node_version" | cut -d. -f1)
    if [[ "$node_major" -ge 18 ]]; then
        pass "v${node_version}"
    else
        fail "v${node_version} - need 18+"
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

step "Docker"
if command -v docker &>/dev/null; then
    docker_version=$(docker --version 2>/dev/null | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -1)
    pass "v${docker_version}"
else
    warn "not found - needed for docker compose up"
fi

step "Docker Compose"
if docker compose version &>/dev/null 2>&1; then
    compose_version=$(docker compose version 2>/dev/null | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -1)
    pass "v${compose_version}"
else
    warn "not found - needed for docker compose up"
fi

# ── Project Files ───────────────────────────────────────────────────
section "Project files"

step ".env"
if [[ -f "$REPO_ROOT/.env" ]]; then
    pass
else
    fail "missing - run: cp .env.example .env"
fi

for env_var in $REQUIRED_ENV_VARS; do
    step ".env has ${env_var}"
    if [[ -f "$REPO_ROOT/.env" ]] && grep -q "^${env_var}=" "$REPO_ROOT/.env"; then
        pass
    else
        fail "${env_var} not set in .env"
    fi
done

step "package.json"
if [[ -f "$NODE_APP_DIR/package.json" ]]; then
    pass
else
    fail "missing"
fi

# Check lockfile
step "Lockfile"
if [[ -f "$NODE_APP_DIR/package-lock.json" ]]; then
    pass "package-lock.json"
elif [[ -f "$NODE_APP_DIR/yarn.lock" ]]; then
    pass "yarn.lock"
elif [[ -f "$NODE_APP_DIR/pnpm-lock.yaml" ]]; then
    pass "pnpm-lock.yaml"
else
    warn "no lockfile found"
fi

# ── Node.js Dependencies ────────────────────────────────────────────
section "Node.js dependencies"

step "node_modules"
if [[ -d "$NODE_APP_DIR/node_modules" ]]; then
    pkg_count=$(find "$NODE_APP_DIR/node_modules" -maxdepth 1 -mindepth 1 -type d 2>/dev/null | wc -l)
    pkg_count="${pkg_count//[^0-9]/}"
    pass "${pkg_count} packages"
else
    fail "missing - run: lib/stacks/node/setup.sh"
fi

# Check specific binaries in node_modules/.bin
for bin_name in $NODE_BIN_CHECKS; do
    step "$bin_name"
    if [[ -x "$NODE_APP_DIR/node_modules/.bin/${bin_name}" ]]; then
        pass
    else
        fail "not installed"
    fi
done

# ── Smoke Tests ──────────────────────────────────────────────────
section "Smoke tests"

step "eslint"
if [[ -x "$NODE_APP_DIR/node_modules/.bin/eslint" ]]; then
    eslint_output=$("$NODE_APP_DIR/node_modules/.bin/eslint" --version 2>/dev/null)
    pass "v${eslint_output#v}"
elif command -v eslint &>/dev/null; then
    eslint_output=$(eslint --version 2>/dev/null)
    pass "v${eslint_output#v} (global)"
else
    skip "eslint not installed"
fi

step "test runner"
if [[ -x "$NODE_APP_DIR/node_modules/.bin/jest" ]]; then
    jest_version=$("$NODE_APP_DIR/node_modules/.bin/jest" --version 2>/dev/null)
    pass "jest v${jest_version}"
elif [[ -x "$NODE_APP_DIR/node_modules/.bin/vitest" ]]; then
    pass "vitest"
else
    skip "no test runner found (jest/vitest)"
fi

step "tsc"
if [[ -x "$NODE_APP_DIR/node_modules/.bin/tsc" ]]; then
    tsc_version=$("$NODE_APP_DIR/node_modules/.bin/tsc" --version 2>/dev/null | grep -oE '[0-9]+\.[0-9]+\.[0-9]+')
    pass "v${tsc_version}"
elif command -v tsc &>/dev/null; then
    tsc_version=$(tsc --version 2>/dev/null | grep -oE '[0-9]+\.[0-9]+\.[0-9]+')
    pass "v${tsc_version} (global)"
else
    skip "TypeScript not installed"
fi

# ── Summary ────────────────────────────────────────────────────────
echo ""
divider
echo ""

if [[ $FAILED -eq 0 ]]; then
    msg="${PASSED}/${TOTAL} checks passed"
    if [[ $WARNINGS -gt 0 ]]; then
        msg="${msg}, ${WARNINGS} warning(s)"
    fi
    echo -e "  ${GREEN}${BOLD}${msg}${RESET}"
    echo ""
else
    echo -e "  ${RED}${BOLD}${FAILED}/${TOTAL} checks failed${RESET}"
    echo ""
    for f in "${FAILURES[@]}"; do
        echo -e "    ${FAIL}  ${f}"
    done
    echo ""
    echo -e "  ${DIM}Run lib/stacks/node/setup.sh to fix most issues${RESET}"
    echo ""
    exit 1
fi
