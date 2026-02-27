#!/usr/bin/env bash
# =============================================================================
# Python Preflight Checks - Run all Python quality gates before committing
# =============================================================================
# Usage: ./lib/stacks/python/preflight-checks.sh
# =============================================================================

set -uo pipefail

# shellcheck source=../../../lib/stacks/_common.sh
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/../_common.sh"

# ---- CONFIGURATION ----
PROJECT_NAME="${PROJECT_NAME:-my-project}"
PYTHON_DIR="${PYTHON_DIR:-python_agents}"
PYTHON_VENV_PATH="${PYTHON_VENV_PATH:-${PYTHON_DIR}/.venv}"
PYTHON_TEST_DIR="${PYTHON_TEST_DIR:-tests/python}"
COMPOSE_FILE_NAME="${COMPOSE_FILE_NAME:-docker-compose.yml}"
# ---- END CONFIGURATION ----

cd "$PROJECT_ROOT" || exit 1
agent_dir="$PROJECT_ROOT/${PYTHON_DIR}"

# ── Checks ────────────────────────────────────────────────────────
header "Preflight Check (Python) - ${PROJECT_NAME}"
echo -e "  ${DIM}$(date '+%Y-%m-%d %H:%M:%S')${RESET}"
echo ""

# 1. Python agent syntax check
step "Python agent syntax"
t=$(_goat_now)
if [[ -d "$agent_dir" ]] && command -v python3 &>/dev/null; then
    py_errors=0
    py_files=0
    py_error_detail=""
    for f in "$agent_dir"/*.py "$agent_dir"/api/*.py "$agent_dir"/agents/*.py; do
        if [[ -f "$f" ]]; then
            py_files=$((py_files + 1))
            check_output=$(python3 -m py_compile "$f" 2>&1)
            if [[ $? -ne 0 ]]; then
                py_errors=$((py_errors + 1))
                py_error_detail="$check_output"
            fi
        fi
    done
    if [[ $py_errors -eq 0 ]]; then
        pass "${py_files} files $(elapsed_since $t)"
    else
        fail "Python agent syntax (${py_errors} errors)"
        echo "$py_error_detail" | head -5 | while read -r line; do
            echo -e "    ${DIM}${line}${RESET}"
        done
    fi
elif [[ ! -d "$agent_dir" ]]; then
    skip "no ${PYTHON_DIR}/ directory"
else
    skip "python3 not available"
fi

# 2. Python lint (ruff)
step "Python lint (ruff)"
t=$(_goat_now)
RUFF_BIN=""
if command -v ruff &>/dev/null; then
    RUFF_BIN="ruff"
elif [[ -x "$PROJECT_ROOT/${PYTHON_VENV_PATH}/bin/ruff" ]]; then
    RUFF_BIN="$PROJECT_ROOT/${PYTHON_VENV_PATH}/bin/ruff"
fi
if [[ -n "$RUFF_BIN" ]] && [[ -d "$agent_dir" ]]; then
    ruff_output=$($RUFF_BIN check "$agent_dir" 2>&1)
    ruff_exit=$?
    if [[ $ruff_exit -eq 0 ]]; then
        pass "$(elapsed_since $t)"
    else
        ruff_count=$(echo "$ruff_output" | grep -cE "^$agent_dir" || true)
        fail "Python lint (${ruff_count} issues)"
        echo "$ruff_output" | head -10 | while read -r line; do
            echo -e "    ${DIM}${line}${RESET}"
        done
    fi
elif [[ ! -d "$agent_dir" ]]; then
    skip "no ${PYTHON_DIR}/ directory"
else
    skip "ruff not installed (pip install ruff)"
fi

# 3. Python tests (pytest)
step "Tests (pytest)"
t=$(_goat_now)
PYTEST_BIN=""
if command -v pytest &>/dev/null; then
    PYTEST_BIN="pytest"
elif [[ -x "$PROJECT_ROOT/${PYTHON_VENV_PATH}/bin/pytest" ]]; then
    PYTEST_BIN="$PROJECT_ROOT/${PYTHON_VENV_PATH}/bin/pytest"
fi
if [[ -n "$PYTEST_BIN" ]] && [[ -d "$PROJECT_ROOT/${PYTHON_TEST_DIR}" ]]; then
    pytest_output=$(PYTHONPATH="$PROJECT_ROOT/${PYTHON_DIR}" $PYTEST_BIN "$PROJECT_ROOT/${PYTHON_TEST_DIR}/" -q 2>&1)
    pytest_exit=$?
    if [[ $pytest_exit -eq 0 ]]; then
        pytest_summary=$(echo "$pytest_output" | tail -1)
        pass "${pytest_summary} $(elapsed_since $t)"
    else
        fail "Python tests"
        echo "$pytest_output" | tail -15 | while read -r line; do
            echo -e "    ${DIM}${line}${RESET}"
        done
    fi
elif [[ ! -d "$PROJECT_ROOT/${PYTHON_TEST_DIR}" ]]; then
    skip "no ${PYTHON_TEST_DIR}/ directory"
else
    skip "pytest not installed (pip install pytest)"
fi

# 4. Docker Compose validate
step "Docker Compose config"
t=$(_goat_now)
compose_file="$PROJECT_ROOT/${COMPOSE_FILE_NAME}"
if [[ -f "$compose_file" ]] && command -v docker &>/dev/null; then
    compose_output=$(docker compose -f "$compose_file" config --quiet 2>&1)
    compose_exit=$?
    if [[ $compose_exit -eq 0 ]]; then
        service_count=$(docker compose -f "$compose_file" config --services 2>/dev/null | wc -l)
        pass "${service_count} services $(elapsed_since $t)"
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
