#!/usr/bin/env bats
# Test: every .sh file has the correct strict mode declaration

setup() {
    load ../test_helper
}

@test "all scripts have correct strict mode (set -euo pipefail or set -uo pipefail)" {
    local failures=()
    while IFS= read -r file; do
        rel="${file#"$REPO_ROOT/"}"
        content=$(head -n 50 "$file")

        if is_library_file "$rel"; then
            continue
        fi

        if is_strict_exception "$rel"; then
            if ! echo "$content" | grep -qE '^set -uo pipefail'; then
                failures+=("$rel (expected set -uo pipefail)")
            fi
        else
            if ! echo "$content" | grep -qE '^set -euo pipefail'; then
                failures+=("$rel (expected set -euo pipefail)")
            fi
        fi
    done < <(discover_scripts)

    if [[ ${#failures[@]} -gt 0 ]]; then
        printf 'Strict mode missing or incorrect:\n'
        printf '  %s\n' "${failures[@]}"
        return 1
    fi
}
