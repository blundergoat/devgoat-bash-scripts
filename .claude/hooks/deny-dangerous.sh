#!/usr/bin/env bash
# PreToolUse hook: deny dangerous commands
# Exit 2 = block with message. Exit 0 = allow.

set -uo pipefail

INPUT=$(cat)
COMMAND=$(echo "$INPUT" | jq -r '.tool_input.command // empty' 2>/dev/null)

[[ -z "$COMMAND" ]] && exit 0

# rm -rf without explicit path scoping
if echo "$COMMAND" | grep -qE 'rm\s+-[a-zA-Z]*r[a-zA-Z]*f|rm\s+-[a-zA-Z]*f[a-zA-Z]*r' ; then
    if echo "$COMMAND" | grep -qE 'rm\s+-rf\s+/\s|rm\s+-rf\s+/$|rm\s+-rf\s+~|rm\s+-rf\s+\.\s|rm\s+-rf\s+\*'; then
        echo "BLOCKED: rm -rf with dangerous target. Use a specific path instead." >&2
        exit 2
    fi
fi

# Force push
if echo "$COMMAND" | grep -qE 'git\s+push\s+.*--force(?!-with-lease)'; then
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

# .env modifications
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

exit 0
