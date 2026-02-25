#!/usr/bin/env bats
# Test: every .sh file under lib/ has the correct shebang

setup() {
    load ../test_helper
}

@test "all scripts have #!/usr/bin/env bash shebang" {
    local failures=()
    while IFS= read -r file; do
        first_line=$(head -n 1 "$file")
        if [[ "$first_line" != "#!/usr/bin/env bash" ]]; then
            rel="${file#"$REPO_ROOT/"}"
            failures+=("$rel")
        fi
    done < <(discover_scripts)

    if [[ ${#failures[@]} -gt 0 ]]; then
        printf 'Missing shebang:\n'
        printf '  %s\n' "${failures[@]}"
        return 1
    fi
}
