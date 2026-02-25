#!/usr/bin/env bats
# Test: scripts that define show_help() respond to --help

setup() {
    load ../test_helper
}

@test "scripts with show_help() exit 0 on --help" {
    local failures=()
    while IFS= read -r file; do
        rel="${file#"$REPO_ROOT/"}"

        # Skip _common.sh libraries (they don't have --help)
        [[ "$rel" == */_common.sh ]] && continue

        # Only test scripts that define show_help
        if ! grep -q 'show_help()' "$file"; then
            continue
        fi

        if ! bash "$file" --help &>/dev/null; then
            failures+=("$rel")
        fi
    done < <(discover_scripts)

    if [[ ${#failures[@]} -gt 0 ]]; then
        printf 'Failed --help (non-zero exit):\n'
        printf '  %s\n' "${failures[@]}"
        return 1
    fi
}

@test "scripts with show_help() print usage text on --help" {
    local failures=()
    while IFS= read -r file; do
        rel="${file#"$REPO_ROOT/"}"

        [[ "$rel" == */_common.sh ]] && continue

        if ! grep -q 'show_help()' "$file"; then
            continue
        fi

        output=$(bash "$file" --help 2>&1 || true)
        # Help output should contain at least one of: Usage, usage, USAGE, or the script name
        if ! echo "$output" | grep -qiE "(usage|options|help)"; then
            failures+=("$rel")
        fi
    done < <(discover_scripts)

    if [[ ${#failures[@]} -gt 0 ]]; then
        printf 'Missing usage text on --help:\n'
        printf '  %s\n' "${failures[@]}"
        return 1
    fi
}
