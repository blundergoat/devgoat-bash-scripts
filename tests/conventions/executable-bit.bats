#!/usr/bin/env bats
# Test: every .sh file under lib/ has the executable bit set

setup() {
    load ../test_helper
}

@test "all scripts have executable bit set" {
    local failures=()
    while IFS= read -r file; do
        if [[ ! -x "$file" ]]; then
            rel="${file#"$REPO_ROOT/"}"
            failures+=("$rel")
        fi
    done < <(discover_scripts)

    if [[ ${#failures[@]} -gt 0 ]]; then
        printf 'Not executable:\n'
        printf '  %s\n' "${failures[@]}"
        return 1
    fi
}
