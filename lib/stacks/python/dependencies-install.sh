#!/usr/bin/env bash
# =============================================================================
# Python Install Dependencies - Installs packages from requirements.txt
# =============================================================================
# Usage: ./lib/stacks/python/dependencies-install.sh
#
# Creates a virtualenv (if missing) and installs exact versions from
# requirements.txt. Use after cloning, switching branches, or when
# requirements files change.
# =============================================================================

set -euo pipefail

source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/../_common.sh"

# ---- CONFIGURATION ----
PROJECT_NAME="${PROJECT_NAME:-my-project}"
PYTHON_DIR_NAME="${PYTHON_DIR_NAME:-python_app}"
PYTHON_APP_DIR="${PYTHON_APP_DIR:-$PROJECT_ROOT/$PYTHON_DIR_NAME}"
VENV_DIR="${VENV_DIR:-$PYTHON_APP_DIR/.venv}"
PYTHON_REQUIREMENTS="${PYTHON_REQUIREMENTS:-$PYTHON_APP_DIR/requirements.txt}"
# ---- END CONFIGURATION ----

# ── Header ──────────────────────────────────────────────────────────
echo ""
echo -e "${BOLD}  ${PROJECT_NAME} - Install Python Dependencies${RESET}"
echo -e "  ${DIM}$(printf '─%.0s' {1..44})${RESET}"
echo ""
echo -e "  ${BOLD}Python (pip)${RESET}"
echo ""

if ! command -v python3 &>/dev/null; then
    step "python3"
    fail "not found"
else
    # Create venv if missing
    step "Python venv"
    if [[ -f "$VENV_DIR/bin/python" ]]; then
        pass "exists"
    else
        if python3 -m venv "$VENV_DIR" 2>&1; then
            pass "created"
        else
            fail "failed to create venv"
        fi
    fi

    # Install from requirements.txt
    if [[ -f "$VENV_DIR/bin/pip" ]]; then
        step "pip install -r requirements.txt"
        pip_output=$("$VENV_DIR/bin/pip" install -r "$PYTHON_REQUIREMENTS" 2>&1)
        pip_exit=$?
        if [[ $pip_exit -eq 0 ]]; then
            pkg_count=$("$VENV_DIR/bin/pip" list --format=columns 2>/dev/null | tail -n +3 | wc -l)
            pass "${pkg_count} packages"
        else
            fail "pip install failed"
            echo "$pip_output" | tail -5 | while IFS= read -r line; do
                echo -e "    ${DIM}${line}${RESET}"
            done
        fi
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
