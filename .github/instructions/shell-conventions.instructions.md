---
applyTo: "lib/**/*.sh"
---

# Shell Conventions (all scripts)

## Required Structure

Every script must start with:
```bash
#!/usr/bin/env bash
set -euo pipefail
```

**Exception:** Scripts that accumulate failures and report a summary at the end use `set -uo pipefail` (omitting `-e`). See `docs/footguns.md` for the full list.

## CONFIGURATION Block (templates only)

Template scripts place project-specific values at the top:
```bash
# ---- CONFIGURATION ----
PROJECT_NAME="${PROJECT_NAME:-my-project}"
AWS_REGION="${AWS_REGION:-us-east-1}"
# ---- END CONFIGURATION ----
```

Rules:
- Every variable uses `${VAR:-default}` fallbacks
- Default values are intentional placeholders — do not "fix" `my-project` or similar generics
- Users override via environment variables or by editing the block after copying

## Naming and Style

- Filenames: `kebab-case.sh`
- Variables: UPPERCASE for config/environment, lowercase for locals
- Indentation: 4 spaces (no tabs)
- Line length: no hard limit, but keep readable

## Required Features

- **Help flag:** All user-facing scripts implement `-h`/`--help` via a `show_help()` function using `cat << EOF`
- **Argument parsing:** `while [[ $# -gt 0 ]]; do case $1 in ... esac; done`
- **Dry-run:** Support `--dry-run` / `-n` where the script performs destructive or external operations

## Validation Checklist

Before declaring a script done, verify:
1. `set -euo pipefail` (or `-uo` with documented reason)
2. `show_help()` with `-h`/`--help`
3. `# ---- CONFIGURATION ----` block if template
4. Platform handling where relevant
5. Logging style matches sibling scripts in the same directory
6. `chmod +x` set (run `lib/maintenance/make-scripts-executable.sh` if needed)
7. `bash -n` passes
8. `shellcheck` passes
