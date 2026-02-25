#!/usr/bin/env bash
# =============================================================================
# Node.js Update Dependencies - Updates packages to latest versions
# =============================================================================
# Usage: ./lib/stacks/node/dependencies-update.sh
#
# Upgrades packages to the latest versions allowed by semver constraints,
# then runs an audit and smoke test to catch breakage.
# =============================================================================

set -euo pipefail

# shellcheck source=../../../lib/stacks/_common.sh
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/../_common.sh"

# ---- CONFIGURATION ----
PROJECT_NAME="${PROJECT_NAME:-my-project}"
NODE_APP_DIR="${NODE_APP_DIR:-$PROJECT_ROOT}"
PACKAGE_MANAGER="${PACKAGE_MANAGER:-npm}"
# ---- END CONFIGURATION ----

# ── Header ──────────────────────────────────────────────────────────
echo ""
echo -e "${BOLD}  ${PROJECT_NAME} - Update Node.js Dependencies${RESET}"
echo -e "  ${DIM}$(printf '─%.0s' {1..44})${RESET}"
echo ""
echo -e "  ${BOLD}Node.js (${PACKAGE_MANAGER})${RESET}"
echo ""

if ! command -v "$PACKAGE_MANAGER" &>/dev/null; then
    step "$PACKAGE_MANAGER"
    fail "not found - install ${PACKAGE_MANAGER} first"
else
    # Update packages
    step "${PACKAGE_MANAGER} update"
    case "$PACKAGE_MANAGER" in
        npm)
            update_output=$(npm update --prefix "$NODE_APP_DIR" 2>&1)
            ;;
        yarn)
            update_output=$(yarn --cwd "$NODE_APP_DIR" upgrade 2>&1)
            ;;
        pnpm)
            update_output=$(pnpm --dir "$NODE_APP_DIR" update 2>&1)
            ;;
        *)
            fail "Unknown package manager: $PACKAGE_MANAGER"
            update_output=""
            ;;
    esac
    update_exit=$?

    if [[ $update_exit -eq 0 ]]; then
        pass "up to date"
    else
        fail "${PACKAGE_MANAGER} update failed"
        echo "$update_output" | tail -5 | while IFS= read -r line; do
            echo -e "    ${DIM}${line}${RESET}"
        done
    fi

    # Audit
    step "${PACKAGE_MANAGER} audit"
    case "$PACKAGE_MANAGER" in
        npm)
            audit_output=$(npm audit --prefix "$NODE_APP_DIR" 2>&1)
            audit_exit=$?
            ;;
        yarn)
            audit_output=$(yarn --cwd "$NODE_APP_DIR" audit 2>&1)
            audit_exit=$?
            ;;
        pnpm)
            audit_output=$(pnpm --dir "$NODE_APP_DIR" audit 2>&1)
            audit_exit=$?
            ;;
        *)
            audit_output=""
            audit_exit=1
            ;;
    esac

    if [[ $audit_exit -eq 0 ]]; then
        pass "no vulnerabilities"
    else
        vuln_count=$(echo "$audit_output" | grep -ciE "vulnerabilit" || echo "0")
        if [[ "$vuln_count" -gt 0 ]]; then
            warn "audit found issues"
            echo "$audit_output" | grep -iE "(high|critical|moderate|low|vulnerabilit)" | head -5 | while IFS= read -r line; do
                echo -e "    ${DIM}${line}${RESET}"
            done
        else
            warn "audit returned non-zero"
        fi
    fi

    # Smoke test — run build if available
    step "Smoke test (build)"
    pkg_file="$NODE_APP_DIR/package.json"
    if [[ -f "$pkg_file" ]] && grep -q '"build"' "$pkg_file"; then
        case "$PACKAGE_MANAGER" in
            npm)  build_output=$(npm run --prefix "$NODE_APP_DIR" build 2>&1) ;;
            yarn) build_output=$(yarn --cwd "$NODE_APP_DIR" build 2>&1) ;;
            pnpm) build_output=$(pnpm --dir "$NODE_APP_DIR" run build 2>&1) ;;
            *)    build_output=""; ;;
        esac
        build_exit=$?
        if [[ $build_exit -eq 0 ]]; then
            pass
        else
            fail "build failed after update"
            echo "$build_output" | tail -5 | while IFS= read -r line; do
                echo -e "    ${DIM}${line}${RESET}"
            done
        fi
    else
        skip "no build script in package.json"
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
