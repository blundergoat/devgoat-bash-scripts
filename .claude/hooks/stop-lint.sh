#!/usr/bin/env bash
# Stop hook: stack-adaptive lint check after every Claude turn
# MUST exit 0 even when errors found (non-zero = infinite fix loops)

# Infinite loop guard
if [[ "${STOP_HOOK_ACTIVE:-}" == "1" ]]; then exit 0; fi
export STOP_HOOK_ACTIVE=1

repo_root=$(git rev-parse --show-toplevel 2>/dev/null) || exit 0
cd "$repo_root" || exit 0

# Check for modified .sh files
changed_sh=$(git diff --name-only 2>/dev/null | grep '\.sh$' || true)
[[ -z "$changed_sh" ]] && exit 0

# Syntax check
while IFS= read -r f; do
    [[ -f "$repo_root/$f" ]] || continue
    output=$(bash -n "$repo_root/$f" 2>&1) || {
        echo "Syntax error in $f:" >&2
        echo "$output" >&2
    }
done <<< "$changed_sh"

# Shellcheck (if available)
if command -v shellcheck &>/dev/null; then
    while IFS= read -r f; do
        [[ -f "$repo_root/$f" ]] || continue
        output=$(shellcheck -x -S warning "$repo_root/$f" 2>&1) || {
            echo "Shellcheck issues in $f:" >&2
            echo "$output" | head -20 >&2
        }
    done <<< "$changed_sh"
fi

exit 0
