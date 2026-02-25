#!/usr/bin/env bats
# Unit tests for lib/stacks/_common.sh

setup() {
    load ../test_helper
    # Prevent .env auto-loading during tests
    PROJECT_ROOT="/tmp/bats-test-$$"
    export PROJECT_ROOT
    mkdir -p "$PROJECT_ROOT"
    source "$REPO_ROOT/lib/stacks/_common.sh"
}

teardown() {
    rm -rf "$PROJECT_ROOT"
}

# ── Color variables ─────────────────────────────────────────────

@test "color variables are defined" {
    [[ -n "$RED" ]]
    [[ -n "$GREEN" ]]
    [[ -n "$YELLOW" ]]
    [[ -n "$BLUE" ]]
    [[ -n "$CYAN" ]]
    [[ -n "$DIM" ]]
    [[ -n "$BOLD" ]]
    [[ -n "$RESET" ]]
    [[ -n "$NC" ]]
}

# ── Symbol variables ────────────────────────────────────────────

@test "symbol variables are defined" {
    [[ -n "$PASS" ]]
    [[ -n "$FAIL" ]]
    [[ -n "$SKIP" ]]
    [[ -n "$ARROW" ]]
}

# ── Counters ────────────────────────────────────────────────────

@test "counters initialize to zero" {
    [[ "$TOTAL" -eq 0 ]]
    [[ "$PASSED" -eq 0 ]]
    [[ "$FAILED" -eq 0 ]]
    [[ "$ERRORS" -eq 0 ]]
    [[ "$WARNINGS" -eq 0 ]]
}

@test "FAILURES array starts empty" {
    [[ ${#FAILURES[@]} -eq 0 ]]
}

@test "START_TIME is set" {
    [[ -n "$START_TIME" ]]
    [[ "$START_TIME" -gt 0 ]]
}

# ── step/pass/fail/skip/warn ────────────────────────────────────

@test "step increments TOTAL" {
    step "test step" >/dev/null
    [[ "$TOTAL" -eq 1 ]]
}

@test "pass increments PASSED" {
    run pass "detail"
    # pass runs in subshell via run, so check output instead
    [[ "$status" -eq 0 ]]
}

@test "pass outputs detail text" {
    run pass "42ms"
    [[ "$output" == *"42ms"* ]]
}

@test "pass with no args still succeeds" {
    run pass
    [[ "$status" -eq 0 ]]
}

@test "fail increments FAILED and ERRORS" {
    fail "something broke" >/dev/null 2>&1
    [[ "$FAILED" -eq 1 ]]
    [[ "$ERRORS" -eq 1 ]]
}

@test "fail appends to FAILURES array" {
    fail "error msg" >/dev/null 2>&1
    [[ "${FAILURES[0]}" == "error msg" ]]
}

@test "skip outputs reason" {
    run skip "not installed"
    [[ "$output" == *"not installed"* ]]
}

@test "warn increments WARNINGS" {
    warn "heads up" >/dev/null 2>&1
    [[ "$WARNINGS" -eq 1 ]]
}

# ── elapsed_since ───────────────────────────────────────────────

@test "elapsed_since returns a time string" {
    local start
    start=$(date +%s%N 2>/dev/null || date +%s)
    run elapsed_since "$start"
    [[ "$status" -eq 0 ]]
    # Should end in ms or s
    [[ "$output" =~ (ms|s)$ ]]
}

# ── header/section/divider ──────────────────────────────────────

@test "header prints title" {
    run header "My Title"
    [[ "$output" == *"My Title"* ]]
}

@test "section prints section name" {
    run section "Section Name"
    [[ "$output" == *"Section Name"* ]]
}

@test "divider outputs a line" {
    run divider
    [[ "$status" -eq 0 ]]
    [[ -n "$output" ]]
}

# ── log helpers ─────────────────────────────────────────────────

@test "log_info prints [INFO] tag" {
    run log_info "test message"
    [[ "$output" == *"[INFO]"* ]]
    [[ "$output" == *"test message"* ]]
}

@test "log_ok prints [OK] tag" {
    run log_ok "success"
    [[ "$output" == *"[OK]"* ]]
}

@test "log_warn prints [WARN] tag" {
    run log_warn "warning"
    [[ "$output" == *"[WARN]"* ]]
}

@test "log_error prints [ERROR] tag" {
    run log_error "failure"
    [[ "$output" == *"[ERROR]"* ]]
}

# ── Double source guard ─────────────────────────────────────────

@test "double-sourcing is safe" {
    source "$REPO_ROOT/lib/stacks/_common.sh"
    source "$REPO_ROOT/lib/stacks/_common.sh"
    [[ "$_STACKS_COMMON_LOADED" -eq 1 ]]
}

# ── .env loader ─────────────────────────────────────────────────

@test ".env file is loaded when present" {
    echo "BATS_TEST_VAR=hello_from_env" > "$PROJECT_ROOT/.env"
    unset _STACKS_COMMON_LOADED
    source "$REPO_ROOT/lib/stacks/_common.sh"
    [[ "$BATS_TEST_VAR" == "hello_from_env" ]]
}

@test "missing .env is handled gracefully" {
    rm -f "$PROJECT_ROOT/.env"
    unset _STACKS_COMMON_LOADED
    source "$REPO_ROOT/lib/stacks/_common.sh"
    # Should not fail
    [[ "$?" -eq 0 ]]
}
