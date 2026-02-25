# Move all script directories under `lib/`

## Context

All script directories (`ai-cli/`, `aws/`, `codegen/`, `dev/`, `maintenance/`, `setup/`, `stacks/`) currently live at the repo root. Moving them into `lib/` keeps the root clean and lets consumers of devgoat-bash-scripts have their own `scripts/` folder alongside the library.

## Changes

### 1. `git mv` all 7 directories into `lib/`

```
ai-cli/       → lib/ai-cli/
aws/          → lib/aws/
codegen/      → lib/codegen/
dev/          → lib/dev/
maintenance/  → lib/maintenance/
setup/        → lib/setup/
stacks/       → lib/stacks/
```

### 2. Update documentation paths

**`CLAUDE.md`** — prefix all script paths with `lib/`:
- `./maintenance/make-scripts-executable.sh` → `./lib/maintenance/make-scripts-executable.sh`
- `./codegen/generate-code-map.sh` → `./lib/codegen/generate-code-map.sh`
- `ai-cli/_common.sh` → `lib/ai-cli/_common.sh`
- `ai-cli/` references → `lib/ai-cli/`
- `stacks/_common.sh` reference → `lib/stacks/_common.sh`

**`README.md`** — prefix all directory/script paths with `lib/`

**`AGENTS.md`** — prefix all directory/script paths with `lib/`

**`GEMINI.md`** — prefix all directory/script paths with `lib/`

### 3. Update one config default

**`lib/stacks/php/preflight-checks.sh`** — change `COMPLEXITY_SCRIPT` default:
- `stacks/php/check-complexity.php` → `lib/stacks/php/check-complexity.php`

### 4. No changes needed for

- All internal `source` commands (use relative `BASH_SOURCE[0]` paths)
- All `PROJECT_ROOT` detection (uses `git rev-parse --show-toplevel`)
- `maintenance/make-scripts-executable.sh` (finds REPO_ROOT via git, searches from there)
- `.gitignore` (no directory-specific entries affected)

## Verification

- `bash -n lib/stacks/_common.sh` and `bash -n lib/stacks/**/*.sh` — syntax still passes
- `grep -r 'stacks/php/check-complexity' lib/` — confirms updated default
- `ls lib/` — shows all 7 directories
- Repo root has only `lib/`, `.gitignore`, markdown files, `.claude/`
