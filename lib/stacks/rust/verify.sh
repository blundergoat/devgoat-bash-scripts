#!/usr/bin/env bash
# =============================================================================
# Rust Verify Setup - Checks that Rust tooling and project config are installed
# =============================================================================
# Usage: ./lib/stacks/rust/verify.sh
# =============================================================================

set -uo pipefail

# shellcheck source=../_common.sh
# shellcheck disable=SC1091
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/../_common.sh"

# ---- CONFIGURATION ----
PROJECT_NAME="${PROJECT_NAME:-my-project}"
RUST_APP_DIR="${RUST_APP_DIR:-$PROJECT_ROOT}"
CARGO_MANIFEST="${CARGO_MANIFEST:-$RUST_APP_DIR/Cargo.toml}"
RUST_MIN_VERSION="${RUST_MIN_VERSION:-1.75.0}"
RUN_TEST_BUILD="${RUN_TEST_BUILD:-true}"
RUN_CLIPPY="${RUN_CLIPPY:-false}"
# ---- END CONFIGURATION ----

show_help() {
    cat << HELP
Usage: $(basename "$0") [OPTIONS]

Verify Rust toolchain and project health.

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

header "${PROJECT_NAME} - Rust Verification"

section "System tools"

step "rustc ${RUST_MIN_VERSION}+"
if command -v rustc &>/dev/null; then
    rustc_version=$(rustc --version 2>/dev/null | awk '{print $2}')
    if version_at_least "$rustc_version" "$RUST_MIN_VERSION"; then
        pass "v${rustc_version}"
    else
        fail "v${rustc_version} - need ${RUST_MIN_VERSION}+"
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

step "rustup"
if command -v rustup &>/dev/null; then
    rustup_version=$(rustup --version 2>/dev/null | awk '{print $2}')
    pass "v${rustup_version}"
else
    warn "not found (recommended for toolchain management)"
fi

section "Project files"

step "Cargo.toml"
if [[ -f "$CARGO_MANIFEST" ]]; then
    pass "${CARGO_MANIFEST}"
else
    fail "missing"
fi

step "Cargo.lock"
if [[ -f "$RUST_APP_DIR/Cargo.lock" ]]; then
    pass
else
    warn "missing (consider committing lockfile for binaries)"
fi

if [[ -f "$CARGO_MANIFEST" ]] && command -v cargo &>/dev/null; then
    section "Smoke tests"

    step "cargo metadata"
    metadata_output=$(cargo metadata --manifest-path "$CARGO_MANIFEST" --no-deps 2>&1)
    metadata_exit=$?
    if [[ $metadata_exit -eq 0 ]]; then
        pass
    else
        fail "metadata parse failed"
        echo "$metadata_output" | tail -5 | while IFS= read -r line; do
            echo -e "    ${DIM}${line}${RESET}"
        done
    fi

    step "cargo check"
    check_output=$(cargo check --manifest-path "$CARGO_MANIFEST" 2>&1)
    check_exit=$?
    if [[ $check_exit -eq 0 ]]; then
        pass
    else
        fail "check failed"
        echo "$check_output" | tail -10 | while IFS= read -r line; do
            echo -e "    ${DIM}${line}${RESET}"
        done
    fi

    if [[ "$RUN_TEST_BUILD" == "true" ]]; then
        step "cargo test --no-run"
        test_output=$(cargo test --manifest-path "$CARGO_MANIFEST" --no-run 2>&1)
        test_exit=$?
        if [[ $test_exit -eq 0 ]]; then
            pass
        else
            fail "test build failed"
            echo "$test_output" | tail -10 | while IFS= read -r line; do
                echo -e "    ${DIM}${line}${RESET}"
            done
        fi
    fi

    step "cargo fmt --check"
    if cargo fmt --version &>/dev/null; then
        fmt_output=$(cargo fmt --manifest-path "$CARGO_MANIFEST" -- --check 2>&1)
        fmt_exit=$?
        if [[ $fmt_exit -eq 0 ]]; then
            pass
        else
            fail "format issues found"
            echo "$fmt_output" | head -10 | while IFS= read -r line; do
                echo -e "    ${DIM}${line}${RESET}"
            done
        fi
    else
        skip "rustfmt not installed"
    fi

    if [[ "$RUN_CLIPPY" == "true" ]]; then
        step "cargo clippy"
        if cargo clippy --version &>/dev/null; then
            clippy_output=$(cargo clippy --manifest-path "$CARGO_MANIFEST" --all-targets --all-features -- -D warnings 2>&1)
            clippy_exit=$?
            if [[ $clippy_exit -eq 0 ]]; then
                pass
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
    echo -e "  ${DIM}Run lib/stacks/rust/setup.sh to fix most issues${RESET}"
    echo ""
    exit 1
fi
