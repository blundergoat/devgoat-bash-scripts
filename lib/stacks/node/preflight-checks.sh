#!/usr/bin/env bash
# =============================================================================
# Node.js Preflight Checks - Run all Node.js quality gates before committing
# =============================================================================
# Usage: ./lib/stacks/node/preflight-checks.sh
# =============================================================================

set -uo pipefail

# shellcheck source=../../../lib/stacks/_common.sh
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/../_common.sh"

# ---- CONFIGURATION ----
PROJECT_NAME="${PROJECT_NAME:-my-project}"
NODE_APP_DIR="${NODE_APP_DIR:-$PROJECT_ROOT}"
PACKAGE_MANAGER="${PACKAGE_MANAGER:-npm}"
COMPOSE_FILE_NAME="${COMPOSE_FILE_NAME:-docker-compose.yml}"
# ---- END CONFIGURATION ----

cd "$PROJECT_ROOT" || exit 1

# ── Package manager helper ────────────────────────────────────────
pm_run() {
    local script_name="$1"
    case "$PACKAGE_MANAGER" in
        npm)  npm run --prefix "$NODE_APP_DIR" "$script_name" ;;
        yarn) yarn --cwd "$NODE_APP_DIR" "$script_name" ;;
        pnpm) pnpm --dir "$NODE_APP_DIR" run "$script_name" ;;
    esac
}

has_script() {
    local script_name="$1"
    local pkg_file="$NODE_APP_DIR/package.json"
    [[ -f "$pkg_file" ]] && grep -q "\"${script_name}\"" "$pkg_file"
}

# ── Checks ────────────────────────────────────────────────────────
header "Preflight Check (Node.js) - ${PROJECT_NAME}"
echo -e "  ${DIM}$(date '+%Y-%m-%d %H:%M:%S')${RESET}"
echo ""

# 1. ESLint
step "Lint (eslint)"
t=$(date +%s%N)
if [[ -x "$NODE_APP_DIR/node_modules/.bin/eslint" ]]; then
    lint_output=$("$NODE_APP_DIR/node_modules/.bin/eslint" "$NODE_APP_DIR" --max-warnings 0 2>&1)
    lint_exit=$?
    if [[ $lint_exit -eq 0 ]]; then
        pass "$(elapsed_since "$t")"
    else
        lint_count=$(echo "$lint_output" | grep -cE "^\s+[0-9]+:[0-9]+" || true)
        fail "eslint (${lint_count} issues)"
        echo "$lint_output" | tail -10 | while read -r line; do
            echo -e "    ${DIM}${line}${RESET}"
        done
    fi
elif has_script "lint"; then
    lint_output=$(pm_run "lint" 2>&1)
    lint_exit=$?
    if [[ $lint_exit -eq 0 ]]; then
        pass "$(elapsed_since "$t")"
    else
        fail "lint script failed"
        echo "$lint_output" | tail -10 | while read -r line; do
            echo -e "    ${DIM}${line}${RESET}"
        done
    fi
else
    skip "eslint not installed and no lint script"
fi

# 2. TypeScript type check
step "Type check (tsc)"
t=$(date +%s%N)
if [[ -x "$NODE_APP_DIR/node_modules/.bin/tsc" && -f "$NODE_APP_DIR/tsconfig.json" ]]; then
    tsc_output=$("$NODE_APP_DIR/node_modules/.bin/tsc" --noEmit --project "$NODE_APP_DIR/tsconfig.json" 2>&1)
    tsc_exit=$?
    if [[ $tsc_exit -eq 0 ]]; then
        pass "$(elapsed_since "$t")"
    else
        tsc_count=$(echo "$tsc_output" | grep -c "error TS" || true)
        fail "tsc (${tsc_count} errors)"
        echo "$tsc_output" | head -10 | while read -r line; do
            echo -e "    ${DIM}${line}${RESET}"
        done
    fi
elif has_script "typecheck"; then
    tsc_output=$(pm_run "typecheck" 2>&1)
    tsc_exit=$?
    if [[ $tsc_exit -eq 0 ]]; then
        pass "$(elapsed_since "$t")"
    else
        fail "typecheck script failed"
    fi
else
    skip "tsc not available or no tsconfig.json"
fi

# 3. Tests
step "Tests"
t=$(date +%s%N)
if [[ -x "$NODE_APP_DIR/node_modules/.bin/jest" ]]; then
    test_output=$("$NODE_APP_DIR/node_modules/.bin/jest" --ci --passWithNoTests 2>&1)
    test_exit=$?
    if [[ $test_exit -eq 0 ]]; then
        test_summary=$(echo "$test_output" | grep -E "Tests:|Test Suites:" | tail -1)
        pass "${test_summary:-ok} $(elapsed_since "$t")"
    else
        fail "jest tests"
        echo "$test_output" | tail -15 | while read -r line; do
            echo -e "    ${DIM}${line}${RESET}"
        done
    fi
elif [[ -x "$NODE_APP_DIR/node_modules/.bin/vitest" ]]; then
    test_output=$("$NODE_APP_DIR/node_modules/.bin/vitest" run 2>&1)
    test_exit=$?
    if [[ $test_exit -eq 0 ]]; then
        pass "$(elapsed_since "$t")"
    else
        fail "vitest tests"
        echo "$test_output" | tail -15 | while read -r line; do
            echo -e "    ${DIM}${line}${RESET}"
        done
    fi
elif has_script "test"; then
    test_output=$(pm_run "test" 2>&1)
    test_exit=$?
    if [[ $test_exit -eq 0 ]]; then
        pass "$(elapsed_since "$t")"
    else
        fail "test script failed"
    fi
else
    skip "no test runner found (jest/vitest)"
fi

# 4. Docker Compose validate
step "Docker Compose config"
t=$(date +%s%N)
compose_file="$PROJECT_ROOT/${COMPOSE_FILE_NAME}"
if [[ -f "$compose_file" ]] && command -v docker &>/dev/null; then
    compose_output=$(docker compose -f "$compose_file" config --quiet 2>&1)
    compose_exit=$?
    if [[ $compose_exit -eq 0 ]]; then
        service_count=$(docker compose -f "$compose_file" config --services 2>/dev/null | wc -l)
        pass "${service_count} services $(elapsed_since "$t")"
    else
        fail "Docker Compose config"
        echo "$compose_output" | head -5 | while read -r line; do
            echo -e "    ${DIM}${line}${RESET}"
        done
    fi
elif [[ ! -f "$compose_file" ]]; then
    skip "no ${COMPOSE_FILE_NAME}"
else
    skip "docker not available"
fi

summary
