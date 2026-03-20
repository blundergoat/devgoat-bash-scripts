#!/usr/bin/env bash
# PreToolUse hook: deny dangerous commands and file writes
# Exit 2 = block with message. Exit 0 = allow.
# Handles Bash (command patterns), Write/Edit (file path patterns).
# Omits -e so every check runs and the final exit 0 is always reached.

set -uo pipefail

INPUT=$(cat)

# Extract fields — try jq first, fall back to grep+sed if jq is missing
if command -v jq &>/dev/null; then
    COMMAND=$(echo "$INPUT" | jq -r '.tool_input.command // empty' 2>/dev/null)
    FILE_PATH=$(echo "$INPUT" | jq -r '.tool_input.file_path // empty' 2>/dev/null)
else
    COMMAND=$(echo "$INPUT" | grep -o '"command"[[:space:]]*:[[:space:]]*"[^"]*"' | sed 's/^"command"[[:space:]]*:[[:space:]]*"//;s/"$//' 2>/dev/null || true)
    FILE_PATH=$(echo "$INPUT" | grep -o '"file_path"[[:space:]]*:[[:space:]]*"[^"]*"' | sed 's/^"file_path"[[:space:]]*:[[:space:]]*"//;s/"$//' 2>/dev/null || true)
fi

# Nothing to check
[[ -z "$COMMAND" ]] && [[ -z "$FILE_PATH" ]] && exit 0

# --- Write/Edit tool: check file path ---
if [[ -n "$FILE_PATH" ]]; then
    # .env file modifications
    if echo "$FILE_PATH" | grep -qE '(^|/)\.env($|\.)'; then
        echo "BLOCKED: .env file modification. Edit .env files manually." >&2
        exit 2
    fi

    # Lockfile modifications
    if echo "$FILE_PATH" | grep -qE '(^|/)(package-lock\.json|pnpm-lock\.yaml|composer\.lock|Cargo\.lock|yarn\.lock)$'; then
        echo "BLOCKED: lockfile modification. Use the package manager." >&2
        exit 2
    fi

    # Generated code modifications
    if echo "$FILE_PATH" | grep -qE '\.(generated|min)\.(js|css|sh)$'; then
        echo "BLOCKED: generated file modification. Regenerate from source." >&2
        exit 2
    fi
fi

# --- Bash tool: check command ---
[[ -z "$COMMAND" ]] && exit 0

# rm -rf without explicit path scoping
if echo "$COMMAND" | grep -qE 'rm\s+-[a-zA-Z]*r[a-zA-Z]*f|rm\s+-[a-zA-Z]*f[a-zA-Z]*r' ; then
    if echo "$COMMAND" | grep -qE 'rm\s+-rf\s+/\s|rm\s+-rf\s+/$|rm\s+-rf\s+~|rm\s+-rf\s+\.\s|rm\s+-rf\s+\*'; then
        echo "BLOCKED: rm -rf with dangerous target. Use a specific path instead." >&2
        exit 2
    fi
fi

# Force push (allow --force-with-lease)
if echo "$COMMAND" | grep -qE 'git\s+push\s+.*--force' && ! echo "$COMMAND" | grep -qF 'force-with-lease'; then
    echo "BLOCKED: git push --force. Use --force-with-lease instead." >&2
    exit 2
fi

# Push to main/master/production
if echo "$COMMAND" | grep -qE 'git\s+push\s+(origin\s+)?(main|master|production)\b'; then
    echo "BLOCKED: direct push to main/master/production. Use a feature branch and PR." >&2
    exit 2
fi

# chmod 777
if echo "$COMMAND" | grep -qE 'chmod\s+777'; then
    echo "BLOCKED: chmod 777 is overly permissive. Use specific permissions (755, 644, etc.)." >&2
    exit 2
fi

# Pipe to shell
if echo "$COMMAND" | grep -qE '(curl|wget)\s.*\|\s*(bash|sh|zsh)'; then
    echo "BLOCKED: pipe-to-shell pattern. Download first, inspect, then execute." >&2
    exit 2
fi

# .env modifications via Bash
if echo "$COMMAND" | grep -qE '(>|>>|tee|sed\s+-i|vim|nano|cat\s+>)\s*\.env'; then
    echo "BLOCKED: .env file modification. Edit .env files manually." >&2
    exit 2
fi

# Skip commit hooks
if echo "$COMMAND" | grep -qE 'git\s+commit\s+.*--no-verify|git\s+commit\s+.*-n\b'; then
    echo "BLOCKED: --no-verify skips safety hooks. Fix the hook failure instead." >&2
    exit 2
fi

# Direct edits to CONFIGURATION block values (template placeholders)
if echo "$COMMAND" | grep -qE 'sed\s.*CONFIGURATION|awk\s.*CONFIGURATION'; then
    echo "BLOCKED: CONFIGURATION blocks are template placeholders. Do not modify values directly — users override via environment variables." >&2
    exit 2
fi

# Lockfile modifications via Bash (two-step: check name, then write operation)
if echo "$COMMAND" | grep -qE '\b(package-lock\.json|pnpm-lock\.yaml|composer\.lock|Cargo\.lock|yarn\.lock)\b'; then
    if echo "$COMMAND" | grep -qE 'sed\s+-i|>\s|>>\s|\btee\b|\bvim\b|\bnano\b'; then
        echo "BLOCKED: lockfile modification. Use the package manager to update lockfiles." >&2
        exit 2
    fi
fi

# Generated code modifications via Bash
if echo "$COMMAND" | grep -qE '\.(generated|min)\.(js|css|sh)\b'; then
    if echo "$COMMAND" | grep -qE 'sed\s+-i|>\s|>>\s|\btee\b|\bvim\b|\bnano\b'; then
        echo "BLOCKED: generated file modification. Regenerate from source instead." >&2
        exit 2
    fi
fi

exit 0
