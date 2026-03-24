# Bash Conventions — devgoat-bash-scripts

## Shell Standard

Every script starts with:

```bash
#!/usr/bin/env bash
set -euo pipefail
```

**Exception:** Scripts that accumulate failures and report a summary use `set -uo pipefail` (omitting `-e`). Document the reason in `docs/footguns.md`.

## Quality Commands

Run before declaring any script done:

```bash
bash -n path/to/script.sh            # Syntax-check (catches unmatched quotes, missing do/done)
shellcheck path/to/script.sh         # Lint (catches unquoted variables, useless cats, etc.)
bats tests/ --recursive              # Run the full test suite
./preflight-checks.sh                # Composite quality gate (runs all of the above)
```

Fixing shellcheck warnings is mandatory. Suppress with `# shellcheck disable=SC####` only when the warning is a false positive, and add a comment explaining why.

## Naming Conventions

- **Filenames:** `kebab-case.sh` (e.g., `install-claude.sh`, `git-change-branch.sh`)
- **Config variables:** UPPERCASE with `${VAR:-default}` fallbacks (e.g., `PROJECT_NAME="${PROJECT_NAME:-my-project}"`)
- **Local variables:** lowercase_snake (e.g., `local line_count=0`)
- **Functions:** snake_case (e.g., `show_help`, `log_error`, `require_aws_auth`)
- **Indentation:** 4 spaces, no tabs

## CONFIGURATION Block

Template scripts place user-editable values at the top between markers:

```bash
# ---- CONFIGURATION ----
PROJECT_NAME="${PROJECT_NAME:-my-project}"
AWS_REGION="${AWS_REGION:-us-east-1}"
# ---- END CONFIGURATION ----
```

Do not replace placeholder defaults. Do not add logic inside the block.

## Logging Conventions — Do and Don't

Logging style is domain-scoped. Match the existing pattern in the target directory:

- `lib/ai-cli/` — direct coloured `echo -e`, no prefix tags
- `lib/stacks/` — `step`/`pass`/`fail` helpers from `_common.sh`
- `lib/aws/` — inline `log`/`success`/`warn`/`error` helpers
- `lib/docker/`, `lib/health/`, `lib/maintenance/` — inline helpers

**BAD:** Importing `_common.sh` step/pass/fail into a `lib/docker/` script (wrong paradigm).
**GOOD:** Defining inline `info`/`warn`/`error` helpers matching `lib/docker/` siblings.

## Help Flag

Every user-facing script implements `-h`/`--help` via a `show_help()` function:

```bash
show_help() {
    cat << EOF
Usage: $0 [OPTIONS]
  -h, --help    Show this help message
EOF
}
```

## Common Dangerous Operations

- **Sourcing shared helpers:** Always use `source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/../_common.sh"` — never relative paths without anchoring.
- **REPO_ROOT resolution:** Use `git rev-parse --show-toplevel`, not chains of `dirname`.
- **`rm -rf` in scripts:** Never use unquoted or unguarded. Always validate the variable first.
- **AWS CLI output:** Always add `// empty` or `// 0` jq fallbacks (AWS can return null fields).

## Testing with Bats

Tests live under `tests/` and use [bats-core](https://github.com/bats-core/bats-core). Each test file sources the script under test and validates outputs and exit codes.

```bash
bats tests/ --recursive               # Run all tests
bats tests/specific-test.bats         # Run a single test file
```
