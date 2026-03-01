# GEMINI.md

Context for Gemini CLI when working on the devgoat-bash-scripts repository.

## Project Identity

devgoat-bash-scripts is a collection of reusable shell scripts organized by domain under `lib/`. Scripts are either **drop-in** (run as-is) or **template** (copy and fill in the `# ---- CONFIGURATION ----` block). No build system, package manager, or test framework.

**Key technologies:** Bash v4+, PHP 8.2+, Python 3.12+, AWS CLI, Terraform, Docker

## Essential Commands

```bash
bash -n path/to/script.sh                              # Syntax-check a script
shellcheck path/to/script.sh                           # Lint a script
./lib/maintenance/make-scripts-executable.sh            # Restore chmod +x on all .sh files
./lib/maintenance/make-scripts-executable.sh --dry-run  # Preview which files need executable bit
./lib/codegen/generate-code-map.sh                      # Inspect repository structure
```

No automated tests. Validate changes by: syntax-checking with `bash -n`, running `shellcheck`, running `--help`, and exercising at least one safe execution path per changed script.

## Hard Rules

- `#!/usr/bin/env bash` + `set -euo pipefail` on every script. Exception: scripts that must continue past failures use `set -uo pipefail` — see `docs/footguns.md`.
- Scripts should be as idempotent as possible.
- Never modify values inside `# ---- CONFIGURATION ----` blocks — those are template placeholders.
- Match the logging paradigm of sibling scripts (ai-cli colors, stacks step/pass/fail, standalone inline functions). See `docs/footguns.md` for details.
- `_common.sh` source patterns differ between `ai-cli/` (same-dir) and `stacks/` (parent traversal) — they are not interchangeable.
- Only `ai-cli/_common.sh` sanitizes WSL PATH. Other domains use bare `command -v`.
- Run `bash -n` and `shellcheck` on changed scripts before declaring done.
- Never commit credentials or secrets.
- When you cause a bug that spans multiple domains, append it to `docs/footguns.md` using the existing format before closing the task.

## Common Workflows

**Adding an ai-cli installer:** Copy an existing `install-*.sh`. Source `_common.sh` via `SCRIPT_DIR`. Use `block_gitbash`, `require_node_or_install`, `verify_native_binary`. No prefix tags in log output.

**Adding a stacks script:** Source `../_common.sh`. Use `step`/`pass`/`fail`/`summary` for checks, `log_info`/`log_ok` for actions. Omit `-e` if the script must report all failures.

**Adding a standalone script (aws/dev/maintenance/tools/codegen):** Self-contained — define inline colors and `log`/`success`/`warn`/`error` functions. Use `set -euo pipefail`. Add CONFIGURATION block if template.

## Commit Format

Short, imperative subjects (e.g., `add amplify variable export script`). One commit per script or workflow. Never commit credentials.

## Context Router

Load these files on demand when working in a specific domain:

| Domain | File | When to load |
|--------|------|-------------|
| All scripts | `.github/instructions/shell-conventions.instructions.md` | Writing or reviewing any `.sh` file |
| `lib/ai-cli/` | `.github/instructions/ai-cli.instructions.md` | Working on AI CLI installers |
| `lib/aws/` | `.github/instructions/aws.instructions.md` | Working on AWS scripts |
| `lib/stacks/` | `.github/instructions/stacks.instructions.md` | Working on stack scripts |
| `lib/dev/`, `lib/maintenance/`, `lib/tools/`, `lib/codegen/` | `.github/instructions/dev.instructions.md` | Working on dev/maintenance/setup/codegen scripts |
| Orientation | `docs/code-map.md` | Understanding repo structure |
| Gotchas | `docs/footguns.md` | Debugging cross-domain issues |
