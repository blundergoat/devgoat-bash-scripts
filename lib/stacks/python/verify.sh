#!/usr/bin/env bash
# =============================================================================
# Python Verify Setup - Checks that Python dependencies and config are installed
# =============================================================================
# Usage: ./lib/stacks/python/verify.sh
#
# Run after setup.sh (or any time) to confirm the Python development environment
# is complete and ready. Checks system tools, venv, installed packages, and
# Python dev tooling (pytest, ruff).
# =============================================================================

set -uo pipefail

source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/../_common.sh"

# ---- CONFIGURATION ----
PROJECT_NAME="${PROJECT_NAME:-my-project}"
PYTHON_DIR_NAME="${PYTHON_DIR_NAME:-python_app}"
PYTHON_APP_DIR="${PYTHON_APP_DIR:-$PROJECT_ROOT/$PYTHON_DIR_NAME}"
VENV_DIR="${VENV_DIR:-$PYTHON_APP_DIR/.venv}"
PYTHON_REQUIREMENTS="${PYTHON_REQUIREMENTS:-$PYTHON_APP_DIR/requirements.txt}"
PYTHON_TEST_DIR="${PYTHON_TEST_DIR:-$PROJECT_ROOT/tests/python}"
# Env vars to verify exist in .env (space-separated)
REQUIRED_ENV_VARS="${REQUIRED_ENV_VARS:-APP_SECRET}"
# Python packages to verify are importable (space-separated)
PYTHON_IMPORT_CHECKS="${PYTHON_IMPORT_CHECKS:-fastapi pydantic}"
# Python packages to verify have binaries in venv (space-separated, format: binary_name:package_name)
PYTHON_BIN_CHECKS="${PYTHON_BIN_CHECKS:-uvicorn:uvicorn pytest:pytest}"
# Python source directories to syntax-check (space-separated glob patterns relative to PYTHON_APP_DIR)
PYTHON_SOURCE_GLOBS="${PYTHON_SOURCE_GLOBS:-*.py api/*.py}"
# Pytest env vars (space-separated KEY=VALUE pairs)
PYTEST_ENV_VARS="${PYTEST_ENV_VARS:-}"
# Python path for pytest
PYTEST_PYTHONPATH="${PYTEST_PYTHONPATH:-$PYTHON_APP_DIR}"
# ---- END CONFIGURATION ----

REPO_ROOT="$PROJECT_ROOT"

# ═════════════════════════════════════════════════════════════════════
header "${PROJECT_NAME} - Python Verification"

# ── System Tools ────────────────────────────────────────────────────
section "System tools"

step "Python 3.12+"
if command -v python3 &>/dev/null; then
    py_version=$(python3 -c 'import sys; print(f"{sys.version_info.major}.{sys.version_info.minor}.{sys.version_info.micro}")')
    py_major=$(python3 -c 'import sys; print(sys.version_info.major)')
    py_minor=$(python3 -c 'import sys; print(sys.version_info.minor)')
    if [[ "$py_major" -ge 3 ]] && [[ "$py_minor" -ge 12 ]]; then
        pass "v${py_version}"
    else
        fail "v${py_version} - need 3.12+"
    fi
else
    fail "not found"
fi

step "ffmpeg"
if command -v ffmpeg &>/dev/null; then
    ffmpeg_version=$(ffmpeg -version 2>/dev/null | head -1 | grep -oE '[0-9]+\.[0-9]+(\.[0-9]+)?' | head -1)
    pass "v${ffmpeg_version}"
else
    fail "not found - run: sudo apt-get install ffmpeg"
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

step "docker-compose.yml"
if [[ -f "$REPO_ROOT/docker-compose.yml" ]]; then
    pass
else
    fail "missing"
fi

# ── Python Dependencies ────────────────────────────────────────────
section "Python dependencies (venv)"

step "Python venv"
if [[ -f "$VENV_DIR/bin/python" ]]; then
    venv_py=$("$VENV_DIR/bin/python" --version 2>/dev/null | grep -oE '[0-9]+\.[0-9]+\.[0-9]+')
    pass "v${venv_py}"
else
    fail "missing - run: lib/stacks/python/setup.sh"
fi

# Check importable Python packages
for pkg in $PYTHON_IMPORT_CHECKS; do
    step "$pkg"
    if [[ -f "$VENV_DIR/bin/python" ]] && "$VENV_DIR/bin/python" -c "import ${pkg}" 2>/dev/null; then
        pkg_ver=$("$VENV_DIR/bin/python" -c "import importlib.metadata; print(importlib.metadata.version('${pkg}'))" 2>/dev/null || echo "unknown")
        pass "v${pkg_ver}"
    else
        fail "not importable"
    fi
done

# Check Python binaries in venv
for entry in $PYTHON_BIN_CHECKS; do
    bin_name="${entry%%:*}"
    pkg_name="${entry##*:}"
    step "$bin_name"
    if [[ -f "$VENV_DIR/bin/${bin_name}" ]]; then
        bin_ver=$("$VENV_DIR/bin/python" -c "import importlib.metadata; print(importlib.metadata.version('${pkg_name}'))" 2>/dev/null || echo "unknown")
        pass "v${bin_ver}"
    else
        fail "not installed"
    fi
done

# ── Python Syntax ──────────────────────────────────────────────────
section "Python source syntax"

py_errors=0
py_files=0
for glob_pattern in $PYTHON_SOURCE_GLOBS; do
    for f in "$PYTHON_APP_DIR"/$glob_pattern; do
        if [[ -f "$f" ]]; then
            py_files=$((py_files + 1))
            rel_path="${f#$REPO_ROOT/}"
            step "$rel_path"
            if "$VENV_DIR/bin/python" -m py_compile "$f" 2>/dev/null; then
                pass
            else
                fail "syntax error"
                py_errors=$((py_errors + 1))
            fi
        fi
    done
done

# ── Smoke Tests ──────────────────────────────────────────────────
section "Smoke tests"

step "pytest runs"
if [[ -f "$VENV_DIR/bin/pytest" ]]; then
    # Build env vars for pytest
    pytest_cmd_env="PYTHONPATH=$PYTEST_PYTHONPATH"
    for env_pair in $PYTEST_ENV_VARS; do
        pytest_cmd_env="$pytest_cmd_env $env_pair"
    done
    pytest_output=$(env $pytest_cmd_env "$VENV_DIR/bin/pytest" "$PYTHON_TEST_DIR/" -q 2>&1)
    pytest_exit=$?
    if [[ $pytest_exit -eq 0 ]]; then
        pytest_summary=$(echo "$pytest_output" | tail -1)
        pass "$pytest_summary"
    else
        fail "tests failing"
    fi
else
    fail "pytest not available"
fi

step "ruff check"
RUFF_BIN=""
if command -v ruff &>/dev/null; then
    RUFF_BIN="ruff"
elif [[ -x "$VENV_DIR/bin/ruff" ]]; then
    RUFF_BIN="$VENV_DIR/bin/ruff"
fi
if [[ -n "$RUFF_BIN" ]] && [[ -d "$PYTHON_APP_DIR" ]]; then
    ruff_output=$($RUFF_BIN check "$PYTHON_APP_DIR" 2>&1)
    ruff_exit=$?
    if [[ $ruff_exit -eq 0 ]]; then
        pass
    else
        ruff_count=$(echo "$ruff_output" | grep -cE "^$PYTHON_APP_DIR" || true)
        fail "ruff (${ruff_count} issues)"
    fi
else
    skip "ruff not installed (pip install ruff)"
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
    echo -e "  ${DIM}Run lib/stacks/python/setup.sh to fix most issues${RESET}"
    echo ""
    exit 1
fi
