#!/usr/bin/env bash
# =============================================================================
# Rust Initial Setup - Installs Rust dependencies for local development
# =============================================================================
# Usage: ./lib/stacks/rust/setup.sh [--locked]
# =============================================================================

set -euo pipefail

# shellcheck source=../_common.sh
# shellcheck disable=SC1091
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/../_common.sh"

# ---- CONFIGURATION ----
PROJECT_NAME="${PROJECT_NAME:-my-project}"
RUST_APP_DIR="${RUST_APP_DIR:-$PROJECT_ROOT}"
CARGO_MANIFEST="${CARGO_MANIFEST:-$RUST_APP_DIR/Cargo.toml}"
RUST_MIN_VERSION="${RUST_MIN_VERSION:-1.75.0}"
QUALITY_CHECK_CMD="${QUALITY_CHECK_CMD:-lib/stacks/rust/preflight-checks.sh}"
START_CMD="${START_CMD:-cargo run}"
# ---- END CONFIGURATION ----

LOCKED=false

show_help() {
    cat << HELP
Usage: $(basename "$0") [OPTIONS]

Set up Rust development dependencies and verify local toolchain.

OPTIONS:
    -h, --help      Show this help message
    --locked        Require Cargo.lock resolution when fetching deps
HELP
}

version_at_least() {
    local current="$1"
    local required="$2"
    local c_major c_minor c_patch r_major r_minor r_patch

    IFS='.' read -r c_major c_minor c_patch <<< "$current"
    IFS='.' read -r r_major r_minor r_patch <<< "$required"

    c_major="${c_major:-0}"
    c_minor="${c_minor:-0}"
    c_patch="${c_patch:-0}"
    r_major="${r_major:-0}"
    r_minor="${r_minor:-0}"
    r_patch="${r_patch:-0}"

    if (( c_major > r_major )); then
        return 0
    elif (( c_major < r_major )); then
        return 1
    fi

    if (( c_minor > r_minor )); then
        return 0
    elif (( c_minor < r_minor )); then
        return 1
    fi

    (( c_patch >= r_patch ))
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

header "${PROJECT_NAME} - Rust Setup"

echo -e "  ${BOLD}Checking prerequisites${RESET}"
echo ""

step "rustc ${RUST_MIN_VERSION}+"
if command -v rustc &>/dev/null; then
    rustc_version=$(rustc --version 2>/dev/null | awk '{print $2}')
    if version_at_least "$rustc_version" "$RUST_MIN_VERSION"; then
        pass "v${rustc_version}"
    else
        fail "found v${rustc_version}, need ${RUST_MIN_VERSION}+"
    fi
else
    fail "not found"
fi

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

if [[ $ERRORS -gt 0 ]]; then
    echo ""
    echo -e "  ${RED}${BOLD}Cannot continue - ${ERRORS} prerequisite(s) missing${RESET}"
    echo ""
    exit 1
fi

section "Installing Rust dependencies"

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

step "cargo check"
if cargo check --manifest-path "$CARGO_MANIFEST" 2>&1 | tail -1; then
    pass
else
    fail "cargo check failed"
fi

echo ""
divider

if [[ $ERRORS -eq 0 ]]; then
    echo ""
    echo -e "  ${GREEN}${BOLD}Setup complete!${RESET}"
    echo ""
    echo -e "  ${DIM}Next steps:${RESET}"
    echo -e "    ${ARROW} Run quality checks:     ${BOLD}${QUALITY_CHECK_CMD}${RESET}"
    echo -e "    ${ARROW} Start app:               ${BOLD}${START_CMD}${RESET}"
    echo ""
else
    echo ""
    echo -e "  ${RED}${BOLD}Setup finished with ${ERRORS} error(s)${RESET}"
    echo ""
    exit 1
fi
