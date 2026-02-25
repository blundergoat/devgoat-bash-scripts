#!/usr/bin/env bats
# Test: every .sh file passes bash -n syntax check

setup() {
    load ../test_helper
}

@test "all scripts pass bash -n syntax check" {
    local failures=()
    while IFS= read -r file; do
        if ! bash -n "$file" 2>/dev/null; then
            rel="${file#"$REPO_ROOT/"}"
            failures+=("$rel")
        fi
    done < <(discover_scripts)

    if [[ ${#failures[@]} -gt 0 ]]; then
        printf 'Syntax errors:\n'
        printf '  %s\n' "${failures[@]}"
        return 1
    fi
}
