#!/usr/bin/env bash
# =============================================================================
# Rust Update Dependencies - Updates Cargo.lock and verifies the build
# =============================================================================
# Usage: ./lib/stacks/rust/dependencies-update.sh
# =============================================================================

set -euo pipefail

# shellcheck source=../_common.sh
# shellcheck disable=SC1091
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/../_common.sh"

# ---- CONFIGURATION ----
PROJECT_NAME="${PROJECT_NAME:-my-project}"
RUST_APP_DIR="${RUST_APP_DIR:-$PROJECT_ROOT}"
CARGO_MANIFEST="${CARGO_MANIFEST:-$RUST_APP_DIR/Cargo.toml}"
RUN_AUDIT_IF_AVAILABLE="${RUN_AUDIT_IF_AVAILABLE:-true}"
# ---- END CONFIGURATION ----

show_help() {
    cat << HELP
Usage: $(basename "$0") [OPTIONS]

Update Rust dependencies and verify project compiles.

OPTIONS:
    -h, --help      Show this help message
HELP
}

if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
    show_help
    exit 0
fi

if [[ $# -gt 0 ]]; then
    echo "Unknown option: $1" >&2
    show_help
    exit 1
fi

echo ""
echo -e "${BOLD}  ${PROJECT_NAME} - Update Rust Dependencies${RESET}"
echo -e "  ${DIM}$(printf '─%.0s' {1..44})${RESET}"
echo ""

step "cargo"
if command -v cargo &>/dev/null; then
    cargo_version=$(cargo --version 2>/dev/null | awk '{print $2}')
    pass "v${cargo_version}"
else
    fail "not found"
fi

step "Cargo.toml"
if [[ -f "$CARGO_MANIFEST" ]]; then
    pass "${CARGO_MANIFEST}"
else
    fail "missing (${CARGO_MANIFEST})"
fi

if [[ $ERRORS -eq 0 ]]; then
    step "cargo update"
    if cargo update --manifest-path "$CARGO_MANIFEST" 2>&1 | tail -1; then
        pass
    else
        fail "cargo update failed"
    fi

    step "cargo check"
    if cargo check --manifest-path "$CARGO_MANIFEST" 2>&1 | tail -1; then
        pass
    else
        fail "cargo check failed"
    fi

    if [[ "$RUN_AUDIT_IF_AVAILABLE" == "true" ]]; then
        step "cargo audit"
        if command -v cargo-audit &>/dev/null; then
            if cargo audit 2>&1 | tail -1; then
                pass
            else
                warn "cargo audit reported findings"
            fi
        else
            skip "cargo-audit not installed"
        fi
    fi
fi

echo ""
divider
echo ""

if [[ $ERRORS -eq 0 ]]; then
    msg="Rust dependencies updated"
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
