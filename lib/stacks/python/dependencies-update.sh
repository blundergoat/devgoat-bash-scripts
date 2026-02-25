#!/usr/bin/env bash
# =============================================================================
# Python Update Dependencies - Updates packages to latest versions
# =============================================================================
# Usage: ./lib/stacks/python/dependencies-update.sh
#
# Upgrades pip packages to the latest versions allowed by constraints,
# then runs an audit and syntax check to catch breakage.
# =============================================================================

set -euo pipefail

# shellcheck source=../../../lib/stacks/_common.sh
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/../_common.sh"

# ---- CONFIGURATION ----
PROJECT_NAME="${PROJECT_NAME:-my-project}"
PYTHON_DIR_NAME="${PYTHON_DIR_NAME:-python_app}"
PYTHON_APP_DIR="${PYTHON_APP_DIR:-$PROJECT_ROOT/$PYTHON_DIR_NAME}"
VENV_DIR="${VENV_DIR:-$PYTHON_APP_DIR/.venv}"
PYTHON_REQUIREMENTS="${PYTHON_REQUIREMENTS:-$PYTHON_APP_DIR/requirements.txt}"
# Python source directories to syntax-check (space-separated glob patterns relative to PYTHON_APP_DIR)
PYTHON_SOURCE_GLOBS="${PYTHON_SOURCE_GLOBS:-*.py api/*.py}"
# ---- END CONFIGURATION ----

# ── Header ──────────────────────────────────────────────────────────
echo ""
echo -e "${BOLD}  ${PROJECT_NAME} - Update Python Dependencies${RESET}"
echo -e "  ${DIM}$(printf '─%.0s' {1..44})${RESET}"
echo ""
echo -e "  ${BOLD}Python (pip)${RESET}"
echo ""

if [[ ! -f "$VENV_DIR/bin/pip" ]]; then
    step "Python venv"
    fail "not found - run lib/stacks/python/setup.sh first"
else
    # Upgrade pip itself
    step "pip self-update"
    "$VENV_DIR/bin/pip" install --upgrade pip >/dev/null 2>&1
    pip_self_exit=$?
    if [[ $pip_self_exit -eq 0 ]]; then
        pip_ver=$("$VENV_DIR/bin/pip" --version 2>/dev/null | grep -oE '[0-9]+\.[0-9]+' | head -1)
        pass "v${pip_ver}"
    else
        warn "pip self-update failed"
    fi

    # Capture before versions
    before=$("$VENV_DIR/bin/pip" freeze 2>/dev/null | sort)

    # Upgrade packages
    step "pip install --upgrade -r requirements.txt"
    pip_output=$("$VENV_DIR/bin/pip" install --upgrade -r "$PYTHON_REQUIREMENTS" 2>&1)
    pip_exit=$?
    if [[ $pip_exit -eq 0 ]]; then
        after=$("$VENV_DIR/bin/pip" freeze 2>/dev/null | sort)
        diff_output=$(diff <(echo "$before") <(echo "$after") || true)
        changed=$(echo "$diff_output" | grep -c "^[<>]" || true)
        changed="${changed:-0}"
        changed="${changed//[^0-9]/}"
        # Each change shows as two diff lines (< old, > new), so divide by 2
        pkg_changed=$(( ${changed:-0} / 2 ))
        if [[ "$pkg_changed" -gt 0 ]]; then
            pass "${pkg_changed} package(s) changed"
            # Show old->new version for each changed package
            echo "$diff_output" | grep "^[<>]" | sed 's/^< //' | sed 's/^> //' | \
                awk -F'==' '{packages[$1] = packages[$1] ? packages[$1] " → " $2 : $2} END {for (p in packages) print p "  " packages[p]}' | sort | \
                while IFS= read -r line; do
                    echo -e "       ${DIM}${line}${RESET}"
                done
        else
            pass "already up to date"
        fi
    else
        fail "pip upgrade failed"
        echo "$pip_output" | tail -5 | while IFS= read -r line; do
            echo -e "    ${DIM}${line}${RESET}"
        done
    fi

    # Audit
    step "pip audit"
    if "$VENV_DIR/bin/pip" check 2>&1 | grep -q "No broken requirements"; then
        pass "no broken requirements"
    else
        check_output=$("$VENV_DIR/bin/pip" check 2>&1)
        issues=$(echo "$check_output" | grep -c "has requirement" || echo "0")
        if [[ "$issues" -gt 0 ]]; then
            warn "${issues} compatibility issue(s)"
            echo "$check_output" | head -5 | while IFS= read -r line; do
                echo -e "    ${DIM}${line}${RESET}"
            done
        else
            pass "all compatible"
        fi
    fi

    # Syntax check
    step "Python source syntax"
    py_errors=0
    for glob_pattern in $PYTHON_SOURCE_GLOBS; do
        for f in "$PYTHON_APP_DIR"/$glob_pattern; do
            if [[ -f "$f" ]] && ! "$VENV_DIR/bin/python" -m py_compile "$f" 2>/dev/null; then
                py_errors=$((py_errors + 1))
            fi
        done
    done
    if [[ $py_errors -eq 0 ]]; then
        pass
    else
        fail "${py_errors} file(s) with syntax errors"
    fi
fi

# ── Summary ─────────────────────────────────────────────────────────
echo ""
divider
echo ""

if [[ $ERRORS -eq 0 ]]; then
    msg="Dependencies updated"
    if [[ $WARNINGS -gt 0 ]]; then
        msg="${msg} with ${WARNINGS} warning(s)"
    fi
    echo -e "  ${GREEN}${BOLD}${msg}${RESET}"
    echo ""
else
    echo -e "  ${RED}${BOLD}Update finished with ${ERRORS} error(s)${RESET}"
    echo ""
    exit 1
fi
