# Code Review Standards — devgoat-bash-scripts

## Review Checklist

For every shell script change, verify:

1. **Strict mode** — `set -euo pipefail` present (or `-uo` with documented exception in `docs/footguns.md`)
2. **Shebang** — `#!/usr/bin/env bash` (not `#!/bin/bash`)
3. **shellcheck clean** — zero warnings at default severity
4. **Help flag** — user-facing scripts implement `-h`/`--help`
5. **Logging style** — matches sibling scripts in the same `lib/` subdirectory
6. **CONFIGURATION block** — template scripts have `# ---- CONFIGURATION ----` with `${VAR:-default}` fallbacks
7. **Cross-domain coupling** — output format changes checked against consumers (especially dashboard PHP parsers)
8. **Shared library impact** — changes to `_common.sh` or `_aws-common.sh` assessed for downstream breakage

## Common Defects

| Defect | What to look for |
|--------|-----------------|
| Unguarded AWS output | `jq` calls without `// empty` or `// 0` fallbacks on AWS CLI output |
| WSL path leaks | `command -v` without WSL-aware check in `lib/ai-cli/` scripts |
| Missing `chmod +x` | New scripts not marked executable |
| Stale references | Renamed files with old name still referenced in README, lib/workflow/help-index.sh, or code-map |
| REPO_ROOT resolution | Using `dirname` instead of `git rev-parse --show-toplevel` |

## Severity Levels

- **Level 1 (isolated):** Style nits, minor improvements. Note and continue.
- **Level 2 (cross-domain/security):** Broken shared helpers, credential handling, output format changes that affect consumers. Full stop, report with file:line evidence, wait for human decision.
