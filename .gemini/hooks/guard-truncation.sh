#!/usr/bin/env bash
# PreToolUse hook: block Write operations that reduce file size by >80%
# Exit 2 = block. Exit 0 = allow.

set -uo pipefail

INPUT=$(cat)

# Extract file_path and content (if write_file)
if command -v jq &>/dev/null; then
    FILE_PATH=$(echo "$INPUT" | jq -r '.tool_input.file_path // empty' 2>/dev/null)
    NEW_CONTENT=$(echo "$INPUT" | jq -r '.tool_input.content // empty' 2>/dev/null)
else
    FILE_PATH=$(echo "$INPUT" | grep -o '"file_path"[[:space:]]*:[[:space:]]*"[^"]*"' | sed 's/^"file_path"[[:space:]]*:[[:space:]]*"//;s/"$//' 2>/dev/null || true)
    NEW_CONTENT=$(echo "$INPUT" | grep -o '"content"[[:space:]]*:[[:space:]]*"[^"]*"' | sed 's/^"content"[[:space:]]*:[[:space:]]*"//;s/"$//' 2>/dev/null || true)
fi

[[ -z "$FILE_PATH" ]] && exit 0
[[ ! -f "$FILE_PATH" ]] && exit 0
[[ -z "$NEW_CONTENT" ]] && exit 0

OLD_SIZE=$(stat -c%s "$FILE_PATH" 2>/dev/null || echo 0)
NEW_SIZE=$(echo -n "$NEW_CONTENT" | wc -c)

# If old file is very small, ignore
[[ $OLD_SIZE -lt 100 ]] && exit 0

# Threshold: 20% of original size (80% reduction)
THRESHOLD=$((OLD_SIZE / 5))

if [[ $NEW_SIZE -lt $THRESHOLD ]]; then
    echo "BLOCKED: Truncation guard. New file size ($NEW_SIZE) is <20% of original ($OLD_SIZE). If this is intentional, delete the file first." >&2
    exit 2
fi

exit 0
