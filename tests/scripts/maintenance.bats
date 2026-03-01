#!/usr/bin/env bats
# Tests for lib/maintenance/ scripts

setup() {
    load ../test_helper
}

@test "make-scripts-executable.sh --help exits 0" {
    run bash "$REPO_ROOT/lib/maintenance/make-scripts-executable.sh" --help
    [[ "$status" -eq 0 ]]
    [[ "$output" == *"Usage"* ]]
}

@test "remove-zone-identifier.sh --help exits 0" {
    run bash "$REPO_ROOT/lib/maintenance/remove-zone-identifier.sh" --help
    [[ "$status" -eq 0 ]]
    [[ "$output" == *"Usage"* ]]
}

@test "remove-zone-identifier.sh --dry-run on empty dir finds nothing" {
    local tmp
    tmp=$(mktemp -d)
    run bash "$REPO_ROOT/lib/maintenance/remove-zone-identifier.sh" --dry-run "$tmp"
    [[ "$status" -eq 0 ]]
    [[ "$output" == *"No Zone.Identifier files found"* ]]
    rm -rf "$tmp"
}
