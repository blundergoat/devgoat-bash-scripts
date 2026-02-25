#!/usr/bin/env bash
# test_helper.bash — shared setup for all bats tests

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
export REPO_ROOT

# Collect all .sh files under lib/
discover_scripts() {
    find "$REPO_ROOT/lib" -name "*.sh" -type f | sort
}

# Scripts that intentionally omit -e (set -uo pipefail instead of set -euo pipefail)
STRICT_EXCEPTIONS=(
    "lib/stacks/php/verify.sh"
    "lib/stacks/python/verify.sh"
    "lib/stacks/node/verify.sh"
    "lib/stacks/php/preflight-checks.sh"
    "lib/stacks/python/preflight-checks.sh"
    "lib/stacks/node/preflight-checks.sh"
    "lib/dev/gpu-check.sh"
    "lib/dev/health-check-localdev.sh"
    "lib/dev/start-dev.sh"
    "lib/maintenance/lint-all.sh"
)

# Library files that don't need their own strict mode
LIBRARY_FILES=(
    "lib/ai-cli/_common.sh"
    "lib/stacks/_common.sh"
)

is_strict_exception() {
    local rel_path="$1"
    for exception in "${STRICT_EXCEPTIONS[@]}"; do
        [[ "$rel_path" == "$exception" ]] && return 0
    done
    return 1
}

is_library_file() {
    local rel_path="$1"
    for lib in "${LIBRARY_FILES[@]}"; do
        [[ "$rel_path" == "$lib" ]] && return 0
    done
    return 1
}
