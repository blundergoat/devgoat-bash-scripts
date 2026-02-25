#!/usr/bin/env bats
# Tests for lib/codegen/ scripts

setup() {
    load ../test_helper
}

@test "generate-code-map.sh --help exits 0" {
    run bash "$REPO_ROOT/lib/codegen/generate-code-map.sh" --help
    [[ "$status" -eq 0 ]]
    [[ "$output" == *"USAGE"* ]] || [[ "$output" == *"Usage"* ]]
}
