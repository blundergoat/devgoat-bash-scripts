#!/usr/bin/env bats
# Test: every .sh file passes shellcheck

setup() {
    load ../test_helper
    if ! command -v shellcheck &>/dev/null; then
        skip "shellcheck not installed"
    fi
}

@test "all scripts pass shellcheck -S warning" {
    local failures=()
    while IFS= read -r file; do
        if ! shellcheck -x -S warning "$file" &>/dev/null; then
            rel="${file#"$REPO_ROOT/"}"
            failures+=("$rel")
        fi
    done < <(discover_scripts)

    if [[ ${#failures[@]} -gt 0 ]]; then
        printf 'Shellcheck warnings:\n'
        printf '  %s\n' "${failures[@]}"
        return 1
    fi
}
