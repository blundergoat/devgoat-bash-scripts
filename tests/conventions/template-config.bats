#!/usr/bin/env bats
# Test: template scripts have matching CONFIGURATION / END CONFIGURATION blocks

setup() {
    load ../test_helper
}

@test "CONFIGURATION blocks are properly opened and closed" {
    local failures=()
    while IFS= read -r file; do
        rel="${file#"$REPO_ROOT/"}"

        open_count=$(grep -c '# ---- CONFIGURATION ----' "$file" || true)
        close_count=$(grep -c '# ---- END CONFIGURATION ----' "$file" || true)

        # Skip scripts that don't have config blocks
        [[ "$open_count" -eq 0 && "$close_count" -eq 0 ]] && continue

        if [[ "$open_count" -ne "$close_count" ]]; then
            failures+=("$rel (open=$open_count, close=$close_count)")
        fi
    done < <(discover_scripts)

    if [[ ${#failures[@]} -gt 0 ]]; then
        printf 'Mismatched CONFIGURATION blocks:\n'
        printf '  %s\n' "${failures[@]}"
        return 1
    fi
}

@test "template scripts use environment variable fallbacks in config blocks" {
    local failures=()
    while IFS= read -r file; do
        rel="${file#"$REPO_ROOT/"}"

        # Only check files that have a CONFIGURATION block
        if ! grep -q '# ---- CONFIGURATION ----' "$file"; then
            continue
        fi

        # Extract lines between CONFIGURATION markers
        config_lines=$(sed -n '/# ---- CONFIGURATION ----/,/# ---- END CONFIGURATION ----/p' "$file" | grep -v '^#' | grep '=' || true)

        # Each assignment should use ${VAR:-default} pattern
        while IFS= read -r line; do
            [[ -z "$line" ]] && continue
            var_name=$(echo "$line" | cut -d= -f1)
            # Skip if it's a compound assignment referencing other config vars
            if ! echo "$line" | grep -qE '\$\{'"$var_name"':-'; then
                failures+=("$rel: $var_name missing \${VAR:-default} pattern")
            fi
        done <<< "$config_lines"
    done < <(discover_scripts)

    if [[ ${#failures[@]} -gt 0 ]]; then
        printf 'Config vars without env fallback:\n'
        printf '  %s\n' "${failures[@]}"
        return 1
    fi
}
