# Base Conventions — devgoat-bash-scripts

## Shell Standard

Every script starts with:

```bash
#!/usr/bin/env bash
set -euo pipefail
```

**Exception:** Scripts that accumulate failures and report a summary at the end use `set -uo pipefail` (omitting `-e`). Document the reason in `docs/footguns.md`.

## Style

- Filenames: `kebab-case.sh`
- Variables: UPPERCASE for config/environment, lowercase for locals
- Indentation: 4 spaces (no tabs)
- Every user-facing script implements `-h`/`--help` via a `show_help()` function

## CONFIGURATION Block (templates only)

Template scripts place project-specific values at the top:

```bash
# ---- CONFIGURATION ----
PROJECT_NAME="${PROJECT_NAME:-my-project}"
AWS_REGION="${AWS_REGION:-us-east-1}"
# ---- END CONFIGURATION ----
```

Do not replace placeholder defaults like `my-project` or `us-east-1`.

## Quality Gates

Run before declaring any script done:

```bash
bash -n path/to/script.sh            # Syntax-check
shellcheck path/to/script.sh         # Lint
bats tests/ --recursive              # Run test suite
```

## Logging

Logging style is domain-scoped — match the existing pattern in the directory:

- `lib/ai-cli/`: direct coloured `echo -e`, no prefix tags
- `lib/stacks/`: `step`/`pass`/`fail` helpers from `_common.sh`
- Standalone domains (`lib/aws/`, `lib/docker/`, etc.): inline `log`/`success`/`warn`/`error` helpers

## Testing with Bats

Tests live under `tests/` and use [bats-core](https://github.com/bats-core/bats-core). Each test file sources the script under test and validates outputs and exit codes. Run `bats tests/ --recursive` to execute the full suite.
