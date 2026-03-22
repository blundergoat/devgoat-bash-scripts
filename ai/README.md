# ai/ — Agent Instructions

Routing map for AI coding agent instruction files.

## Structure

```
ai/
  instructions/
    base.md              # Bash conventions, strict mode, shellcheck, bats
    code-review.md       # Review standards for shell scripts
    git-commit.md        # Commit message format and scope rules
```

## How Agents Use These Files

These are agent-neutral instruction files. Each agent runtime loads them as context:

- **Claude Code** reads `ai/instructions/` via the CLAUDE.md router table
- **Codex** reads `ai/instructions/` via the AGENTS.md router table
- **Gemini CLI** reads `ai/instructions/` via the GEMINI.md router table

For domain-specific conventions applied to file globs, see `.github/instructions/`.
