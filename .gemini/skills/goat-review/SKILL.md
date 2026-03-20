# /goat-review — Structured Shell Script Code Review

Review shell scripts for correctness, convention compliance, and potential issues.

## Instructions

### MUST (cannot skip)
1. **Read ALL changed files** thoroughly before commenting.
2. **Verify every finding is real** by tracing the execution path. NO speculative issues.
3. **Verify repo conventions:**
   - `#!/usr/bin/env bash` shebang.
   - `set -euo pipefail` (check `docs/footguns.md` for exceptions).
   - `-h`/`--help` via `show_help()` for user-facing scripts.
   - 4-space indentation, `kebab-case.sh` filename.
   - `# ---- CONFIGURATION ----` block if template.
   - Consistent logging style with sibling scripts.
4. **Run `shellcheck`** on each changed script.

### SHOULD (skip only with reason)
5. **Check for false positives** by reading surrounding context.
6. **Note uncertainty** rather than asserting a bug if unsure.

### MAY (skip during debugging)
7. **Suggest minor style improvements** if they don't impact readability or performance.

## Output Format
```md
## Review: [Script Name]

### Critical (MUST Fix)
- [file:line] Description + suggested fix

### Non-critical (SHOULD Fix)
- [file:line] Description + suggested fix

### Conventions
- [Convention Status]: shebang, strict mode, help flag, naming, indentation
- [Findings]: list any missing conventions
```
