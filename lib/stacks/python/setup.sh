#!/usr/bin/env bash
# =============================================================================
# Python Initial Setup - Installs Python dependencies for local development
# =============================================================================
# Usage: ./lib/stacks/python/setup.sh
#
# Sets up the Python side of a project: checks prerequisites, copies .env,
# creates a virtualenv, and installs pip packages.
#
# Prerequisites:
#   - Python 3.12+
#   - pip3
# =============================================================================

set -euo pipefail

source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/../_common.sh"

# ---- CONFIGURATION ----
PROJECT_NAME="${PROJECT_NAME:-my-project}"
PYTHON_DIR_NAME="${PYTHON_DIR_NAME:-python_app}"
PYTHON_APP_DIR="${PYTHON_APP_DIR:-$PROJECT_ROOT/$PYTHON_DIR_NAME}"
PYTHON_REQUIREMENTS="${PYTHON_REQUIREMENTS:-$PYTHON_APP_DIR/requirements.txt}"
PYTHON_TEST_REQUIREMENTS="${PYTHON_TEST_REQUIREMENTS:-$PROJECT_ROOT/tests/python/requirements-dev.txt}"
EXTRA_PIP_PACKAGES="${EXTRA_PIP_PACKAGES:-}"
INSTALL_SYSTEM_PACKAGES="${INSTALL_SYSTEM_PACKAGES:-true}"
SYSTEM_PACKAGES="${SYSTEM_PACKAGES:-ffmpeg}"
QUALITY_CHECK_CMD="${QUALITY_CHECK_CMD:-lib/stacks/python/preflight-checks.sh}"
START_CMD="${START_CMD:-docker compose up --build}"
# ---- END CONFIGURATION ----

REPO_ROOT="$PROJECT_ROOT"

# ── Prerequisite checks ────────────────────────────────────────────
header "${PROJECT_NAME} - Python Setup"

echo -e "  ${BOLD}Checking prerequisites${RESET}"
echo ""

step "Python 3.12+"
if command -v python3 &>/dev/null; then
    py_version=$(python3 -c 'import sys; print(f"{sys.version_info.major}.{sys.version_info.minor}")')
    py_major=$(python3 -c 'import sys; print(sys.version_info.major)')
    py_minor=$(python3 -c 'import sys; print(sys.version_info.minor)')
    if [[ "$py_major" -ge 3 ]] && [[ "$py_minor" -ge 12 ]]; then
        pass "v${py_version}"
    else
        fail "found v${py_version}, need 3.12+"
    fi
else
    fail "not found"
fi

step "pip3"
if command -v pip3 &>/dev/null; then
    pip_version=$(pip3 --version 2>/dev/null | grep -oE '[0-9]+\.[0-9]+' | head -1)
    pass "v${pip_version}"
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
else
    cp "$REPO_ROOT/.env.example" "$REPO_ROOT/.env"
    pass "created"
fi

# ── Python dependencies ────────────────────────────────────────────
section "Installing Python dependencies"

step "Create Python venv"
if [[ -d "$PYTHON_APP_DIR/.venv" ]]; then
    pass "already exists"
else
    python3 -m venv "$PYTHON_APP_DIR/.venv"
    pass "created"
fi

step "pip install -r requirements.txt"
if "$PYTHON_APP_DIR/.venv/bin/pip" install -r "$PYTHON_REQUIREMENTS" 2>&1 | tail -1; then
    pass
else
    fail "pip install failed"
fi

# Install extra pip packages if configured
if [[ -n "$EXTRA_PIP_PACKAGES" ]]; then
    for pkg in $EXTRA_PIP_PACKAGES; do
        step "pip install ${pkg}"
        if "$PYTHON_APP_DIR/.venv/bin/pip" install "$pkg" 2>&1 | tail -1; then
            pass
        else
            fail "${pkg} install failed"
        fi
    done
fi

if [[ -f "$PYTHON_TEST_REQUIREMENTS" ]]; then
    step "pip install test deps (pytest)"
    if "$PYTHON_APP_DIR/.venv/bin/pip" install -r "$PYTHON_TEST_REQUIREMENTS" 2>&1 | tail -1; then
        pass
    else
        fail "test deps install failed"
    fi
fi

# ── System packages ──────────────────────────────────────────────
if [[ "$INSTALL_SYSTEM_PACKAGES" == "true" && -n "$SYSTEM_PACKAGES" ]]; then
    section "Installing system packages"

    for pkg in $SYSTEM_PACKAGES; do
        step "$pkg"
        if command -v "$pkg" &>/dev/null; then
            pkg_version=$("$pkg" -version 2>/dev/null | head -1 | grep -oE '[0-9]+\.[0-9]+(\.[0-9]+)?' | head -1 || echo "unknown")
            pass "already installed v${pkg_version}"
        else
            if sudo apt-get install -y -qq "$pkg" 2>&1 | tail -1; then
                pass "installed"
            else
                fail "${pkg} install failed - install manually: sudo apt-get install ${pkg}"
            fi
        fi
    done
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
    echo -e "    ${ARROW} Python venv is at:       ${DIM}${PYTHON_DIR_NAME}/.venv${RESET}"
    echo ""
else
    echo ""
    echo -e "  ${RED}${BOLD}Setup finished with ${ERRORS} error(s)${RESET}"
    echo ""
    exit 1
fi
