# /goat-review - Shell Script Code Review

Review shell scripts for correctness, convention compliance, and potential issues.

## Instructions

1. **Read ALL changed files thoroughly before commenting.** Use `git diff --name-only` to find changed `.sh` files, then read each one in full.
2. **For each finding, verify it's real** by reading surrounding code and tracing the execution path. Do NOT report speculative issues.
3. **Check for false positives** - re-read the context around any suspicious code before flagging it. If unsure, note the uncertainty rather than asserting a bug.
4. **Verify repo conventions** for each script:
   - `#!/usr/bin/env bash` shebang
   - `set -euo pipefail` (or documented exception like `verify.sh`, `gpu-check.sh`)
   - `-h`/`--help` via `show_help()` using `cat << EOF` for user-facing scripts
   - `kebab-case.sh` filename
   - 4-space indentation
   - UPPERCASE for config/env vars, lowercase for locals
   - `# ---- CONFIGURATION ----` block if template script
   - Consistent color/logging style with sibling scripts in the same directory
5. **Run shellcheck** on each changed script and include relevant findings.
6. **Categorize findings:**
   - **Critical:** Bugs, broken logic, missing error handling that causes silent failures, security issues
   - **Non-critical:** Style inconsistencies, minor shellcheck warnings, suggestions for improvement
7. **For external review comments** (Copilot, GitHub suggestions, etc.), investigate each suggestion against the actual codebase before applying. Some suggestions cause breaking changes in shell scripts (e.g., quoting changes that break intentional word splitting).

## Output Format

```
## Review: <script-name>

### Critical
- [file:line] Description of issue + suggested fix

### Non-critical
- [file:line] Description of issue + suggested fix

### Conventions
- ✅ shebang, strict mode, help flag, naming, indentation
- ❌ <any missing conventions>
```
