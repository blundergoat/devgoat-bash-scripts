#!/usr/bin/env bash
# =============================================================================
# Rust Preflight Checks - Run Rust quality gates before committing
# =============================================================================
# Usage: ./lib/stacks/rust/preflight-checks.sh
# =============================================================================

set -uo pipefail

# shellcheck source=../_common.sh
# shellcheck disable=SC1091
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/../_common.sh"

# ---- CONFIGURATION ----
PROJECT_NAME="${PROJECT_NAME:-my-project}"
RUST_APP_DIR="${RUST_APP_DIR:-$PROJECT_ROOT}"
CARGO_MANIFEST="${CARGO_MANIFEST:-$RUST_APP_DIR/Cargo.toml}"
RUN_CLIPPY="${RUN_CLIPPY:-false}"
RUN_TEST_BUILD="${RUN_TEST_BUILD:-true}"
# ---- END CONFIGURATION ----

show_help() {
    cat << HELP
Usage: $(basename "$0") [OPTIONS]

Run Rust preflight checks (fmt/check/test/clippy optional).

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

header "Preflight Check (Rust) - ${PROJECT_NAME}"
echo -e "  ${DIM}$(date '+%Y-%m-%d %H:%M:%S')${RESET}"
echo ""

step "cargo"
if command -v cargo &>/dev/null; then
    pass "$(cargo --version 2>/dev/null | awk '{print $2}')"
else
    fail "not found"
fi

step "Cargo.toml"
if [[ -f "$CARGO_MANIFEST" ]]; then
    pass "${CARGO_MANIFEST}"
else
    fail "missing (${CARGO_MANIFEST})"
fi

if [[ -f "$CARGO_MANIFEST" ]] && command -v cargo &>/dev/null; then
    step "cargo fmt --check"
    t=$(_goat_now)
    if cargo fmt --version &>/dev/null; then
        fmt_output=$(cargo fmt --manifest-path "$CARGO_MANIFEST" -- --check 2>&1)
        fmt_exit=$?
        if [[ $fmt_exit -eq 0 ]]; then
            pass "$(elapsed_since "$t")"
        else
            fail "format issues"
            echo "$fmt_output" | head -10 | while IFS= read -r line; do
                echo -e "    ${DIM}${line}${RESET}"
            done
        fi
    else
        skip "rustfmt not installed"
    fi

    step "cargo check"
    t=$(_goat_now)
    check_output=$(cargo check --manifest-path "$CARGO_MANIFEST" 2>&1)
    check_exit=$?
    if [[ $check_exit -eq 0 ]]; then
        pass "$(elapsed_since "$t")"
    else
        fail "check failed"
        echo "$check_output" | tail -10 | while IFS= read -r line; do
            echo -e "    ${DIM}${line}${RESET}"
        done
    fi

    if [[ "$RUN_TEST_BUILD" == "true" ]]; then
        step "cargo test --no-run"
        t=$(_goat_now)
        test_output=$(cargo test --manifest-path "$CARGO_MANIFEST" --no-run 2>&1)
        test_exit=$?
        if [[ $test_exit -eq 0 ]]; then
            pass "$(elapsed_since "$t")"
        else
            fail "test build failed"
            echo "$test_output" | tail -10 | while IFS= read -r line; do
                echo -e "    ${DIM}${line}${RESET}"
            done
        fi
    fi

    if [[ "$RUN_CLIPPY" == "true" ]]; then
        step "cargo clippy"
        t=$(_goat_now)
        if cargo clippy --version &>/dev/null; then
            clippy_output=$(cargo clippy --manifest-path "$CARGO_MANIFEST" --all-targets --all-features -- -D warnings 2>&1)
            clippy_exit=$?
            if [[ $clippy_exit -eq 0 ]]; then
                pass "$(elapsed_since "$t")"
            else
                fail "clippy warnings/errors"
                echo "$clippy_output" | head -10 | while IFS= read -r line; do
                    echo -e "    ${DIM}${line}${RESET}"
                done
            fi
        else
            skip "clippy not installed"
        fi
    fi
fi

summary
