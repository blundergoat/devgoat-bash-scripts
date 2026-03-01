#!/usr/bin/env bash
# =============================================================================
# Rust Install Dependencies - Fetches crate dependencies for a Rust project
# =============================================================================
# Usage: ./lib/stacks/rust/dependencies-install.sh [--locked]
# =============================================================================

set -euo pipefail

# shellcheck source=../_common.sh
# shellcheck disable=SC1091
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/../_common.sh"

# ---- CONFIGURATION ----
PROJECT_NAME="${PROJECT_NAME:-my-project}"
RUST_APP_DIR="${RUST_APP_DIR:-$PROJECT_ROOT}"
CARGO_MANIFEST="${CARGO_MANIFEST:-$RUST_APP_DIR/Cargo.toml}"
VERIFY_WITH_CARGO_CHECK="${VERIFY_WITH_CARGO_CHECK:-true}"
# ---- END CONFIGURATION ----

LOCKED=false

show_help() {
    cat << HELP
Usage: $(basename "$0") [OPTIONS]

Fetch Rust dependencies from Cargo.toml/Cargo.lock.

OPTIONS:
    -h, --help      Show this help message
    --locked        Require Cargo.lock resolution
HELP
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        -h|--help)
            show_help
            exit 0
            ;;
        --locked)
            LOCKED=true
            shift
            ;;
        *)
            echo "Unknown option: $1" >&2
            show_help
            exit 1
            ;;
    esac
done

echo ""
echo -e "${BOLD}  ${PROJECT_NAME} - Install Rust Dependencies${RESET}"
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
    fetch_args=(--manifest-path "$CARGO_MANIFEST")
    if [[ "$LOCKED" == true ]]; then
        fetch_args+=(--locked)
    fi

    step "cargo fetch"
    if cargo fetch "${fetch_args[@]}" 2>&1 | tail -1; then
        pass
    else
        fail "cargo fetch failed"
    fi

    if [[ "$VERIFY_WITH_CARGO_CHECK" == "true" ]]; then
        step "cargo check"
        if cargo check --manifest-path "$CARGO_MANIFEST" 2>&1 | tail -1; then
            pass
        else
            fail "cargo check failed"
        fi
    fi
fi

echo ""
divider
echo ""

if [[ $ERRORS -eq 0 ]]; then
    echo -e "  ${GREEN}${BOLD}Rust dependencies installed${RESET}"
    echo ""
else
    echo -e "  ${RED}${BOLD}${ERRORS} error(s) during install${RESET}"
    echo ""
    exit 1
fi
