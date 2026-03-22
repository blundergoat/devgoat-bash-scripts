---
applyTo: "lib/stacks/**"
---

# stacks Domain

Language-specific setup, dependency management, and quality gates. Each stack (go/, php/, python/) is independently copyable.

## Shared Library: `_common.sh`

Source pattern (parent-directory traversal):
```bash
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/../_common.sh"
```

**Double-source guard:** `_STACKS_COMMON_LOADED` — safe to source multiple times.

### Auto-runs on Source
- `PROJECT_ROOT` detection via `git rev-parse --show-toplevel`
- `.env` auto-loading via `set -o allexport`

### Color Constants
`RED`, `GREEN`, `YELLOW`, `BLUE`, `CYAN`, `DIM`, `BOLD`, `RESET`, `NC`

### Symbols
`PASS` (green ✔), `FAIL` (red ✘), `SKIP` (yellow ○), `ARROW` (blue ▸)

### Counters
`TOTAL`, `PASSED`, `FAILED`, `ERRORS`, `WARNINGS`, `FAILURES` (array), `START_TIME`

### Preflight/Verify Helpers
| Function | Purpose |
|----------|---------|
| `step "label"` | Print check name, increment TOTAL |
| `pass "detail"` | Print ✔, increment PASSED |
| `fail "msg"` | Print ✘, increment FAILED/ERRORS, append to FAILURES |
| `skip "reason"` | Print ○ with reason |
| `warn "msg"` | Print ⚠, increment WARNINGS |
| `header "title"` | Section header with divider |
| `section "title"` | Bold section title |
| `divider` | Horizontal rule |
| `summary` | Final pass/fail count with elapsed time; exits 1 if any failures |
| `elapsed_since START` | Returns human-readable duration |

### Log Helpers (Go/database style)
| Function | Output |
|----------|--------|
| `log_info MSG` | `[INFO] MSG` |
| `log_ok MSG` | `[OK] MSG` |
| `log_warn MSG` | `[WARN] MSG` |
| `log_error MSG` | `[ERROR] MSG` |

## Strict Mode Exceptions

| Script | Mode | Reason |
|--------|------|--------|
| `php/verify.sh` | `set -uo pipefail` | Must complete all checks before summary |
| `python/verify.sh` | `set -uo pipefail` | Same as above |
| `node/verify.sh` | `set -uo pipefail` | Same as above |
| `php/preflight-checks.sh` | No explicit `set` | Relies on sourced _common.sh; runs all quality gates |
| `python/preflight-checks.sh` | No explicit `set` | Same as above |
| `node/preflight-checks.sh` | No explicit `set` | Same as above |

## Two Script Patterns

1. **Verify/preflight scripts** — Use `step`/`pass`/`fail` + `summary`. Omit `-e` so all checks run.
2. **Action scripts** (setup, dependencies, seed) — Use `log_info`/`log_ok`/`log_error`. Use full `set -euo pipefail` to fail fast.

## Per-Stack Notes

- **Go:** Database management only (migrate, rollback, seed). Requires `golang-migrate` CLI and PostgreSQL client tools.
- **Node.js:** Supports npm/yarn/pnpm via `PACKAGE_MANAGER` config variable. All 5 scripts use a `pm_install`/`pm_run` helper to abstract the package manager. `verify.sh` checks for eslint, jest/vitest, and tsc. `preflight-checks.sh` runs lint, type-check, tests, and Docker Compose validation.
- **PHP:** Includes `check-complexity.php` for cyclomatic complexity analysis. `preflight-checks.sh` supports `--coverage-min=N` flag. Note: `dashboard/` also contains PHP files.
- **Python:** Uses venv-based workflow. `preflight-checks.sh` checks for Docker Compose availability.
