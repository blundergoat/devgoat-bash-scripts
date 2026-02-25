#!/usr/bin/env bash
# =============================================================================
# PHP Update Dependencies - Updates packages to latest versions
# =============================================================================
# Usage: ./lib/stacks/php/dependencies-update.sh
#
# Runs composer update (rewrites composer.lock), followed by a security audit
# and a quick PHPUnit smoke test to catch breakage.
# =============================================================================

set -euo pipefail

source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/../_common.sh"

# ---- CONFIGURATION ----
PROJECT_NAME="${PROJECT_NAME:-my-project}"
# PHPUnit config file
PHPUNIT_CONFIG="${PHPUNIT_CONFIG:-$PROJECT_ROOT/phpunit.xml.dist}"
# ---- END CONFIGURATION ----

REPO_ROOT="$PROJECT_ROOT"

# ── Header ──────────────────────────────────────────────────────────
echo ""
echo -e "${BOLD}  ${PROJECT_NAME} - Update PHP Dependencies${RESET}"
echo -e "  ${DIM}$(printf '─%.0s' {1..44})${RESET}"
echo ""
echo -e "  ${BOLD}PHP (Composer)${RESET}"
echo ""

if ! command -v composer &>/dev/null; then
    step "composer"
    fail "not found"
else
    step "composer update"
    update_output=$(cd "$REPO_ROOT" && composer update 2>&1)
    update_exit=$?
    if [[ $update_exit -eq 0 ]]; then
        changed_lines=$(echo "$update_output" | grep -E "^\s+- (Upgrading|Installing|Removing)" || true)
        updated=$(echo "$changed_lines" | grep -c "." || true)
        updated="${updated//[^0-9]/}"
        if [[ "${updated:-0}" -gt 0 ]]; then
            pass "${updated} package(s) changed"
            echo "$changed_lines" | while IFS= read -r line; do
                echo -e "       ${DIM}${line}${RESET}"
            done
        else
            pass "already up to date"
        fi
    else
        fail "composer update failed"
        echo "$update_output" | tail -5 | while IFS= read -r line; do
            echo -e "    ${DIM}${line}${RESET}"
        done
    fi

    # Security audit
    step "Security audit"
    audit_output=$(cd "$REPO_ROOT" && composer audit 2>&1)
    audit_exit=$?
    if [[ $audit_exit -eq 0 ]]; then
        pass "no vulnerabilities"
    else
        warn "$(echo "$audit_output" | grep -c "Advisory" || echo "?") advisory(s) found"
    fi

    # Quick test
    if [[ -x "$REPO_ROOT/vendor/bin/phpunit" ]]; then
        step "PHPUnit smoke test"
        test_output=$("$REPO_ROOT/vendor/bin/phpunit" --configuration "$PHPUNIT_CONFIG" 2>&1)
        test_exit=$?
        if [[ $test_exit -eq 0 ]]; then
            test_summary=$(echo "$test_output" | grep -oE '[0-9]+ tests, [0-9]+ assertions' || echo "ok")
            pass "$test_summary"
        else
            fail "tests broken after update"
            echo "$test_output" | grep -E "(FAIL|Error)" | head -5 | while IFS= read -r line; do
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
    msg="Dependencies updated"
    if [[ $WARNINGS -gt 0 ]]; then
        msg="${msg} with ${WARNINGS} warning(s)"
    fi
    echo -e "  ${GREEN}${BOLD}${msg}${RESET}"
    echo ""
    echo -e "  ${DIM}Review changes:${RESET}"
    echo -e "    ${ARROW} ${BOLD}git diff composer.lock${RESET}"
    echo ""
else
    echo -e "  ${RED}${BOLD}Update finished with ${ERRORS} error(s)${RESET}"
    echo ""
    exit 1
fi
