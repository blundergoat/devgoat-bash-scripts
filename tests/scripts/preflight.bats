#!/usr/bin/env bats
# Tests for preflight-checks.sh

setup() {
    load ../test_helper
}

@test "preflight-checks.sh --help exits 0" {
    run bash "$REPO_ROOT/preflight-checks.sh" --help
    [[ "$status" -eq 0 ]]
    [[ "$output" == *"Usage"* ]]
}

@test "preflight-checks.sh rejects unknown flags" {
    run bash "$REPO_ROOT/preflight-checks.sh" --invalid-flag
    [[ "$status" -eq 1 ]]
}
