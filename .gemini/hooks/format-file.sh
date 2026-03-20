#!/usr/bin/env bash
# PostToolUse hook: format modified files by extension
# MUST exit 0 even on errors

INPUT=$(cat)

# Extract file_path from Write/Edit tools
if command -v jq &>/dev/null; then
    FILE_PATH=$(echo "$INPUT" | jq -r '.tool_input.file_path // empty' 2>/dev/null)
else
    FILE_PATH=$(echo "$INPUT" | grep -o '"file_path"[[:space:]]*:[[:space:]]*"[^"]*"' | sed 's/^"file_path"[[:space:]]*:[[:space:]]*"//;s/"$//' 2>/dev/null || true)
fi

[[ -z "$FILE_PATH" ]] && exit 0
[[ ! -f "$FILE_PATH" ]] && exit 0

# Format by extension
case "$FILE_PATH" in
    *.sh)
        if command -v shfmt &>/dev/null; then
            shfmt -w "$FILE_PATH"
        fi
        ;;
    *.php)
        if command -v php-cs-fixer &>/dev/null; then
            php-cs-fixer fix "$FILE_PATH" --quiet
        fi
        ;;
esac

exit 0
