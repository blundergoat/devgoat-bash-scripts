# Domain Reference - devgoat-bash-scripts

Technical reference for repo mechanics. This file holds project details that should not live in the runtime loop in `AGENTS.md`.

## Common Workflows

### Adding an ai-cli installer

Copy an existing `install-*.sh`. Source `_common.sh` via `SCRIPT_DIR`. Use `block_gitbash`, `require_node_or_install`, and `verify_native_binary`. Keep output in the ai-cli style: colour only, no prefix tags.

### Adding a stacks script

Source `../_common.sh`. Use `step`/`pass`/`fail`/`summary` for checks and `log_info`/`log_ok` for actions. Omit `-e` only when the script must report all failures before exiting.

### Adding a standalone script

Applicable to `aws/`, `docker/`, `health/`, `workflow/`, `maintenance/`, `tools/`, and `codegen/`. Define inline colours plus local logging helpers. Use `set -euo pipefail` unless the file is a known strict-mode exception.

## Domain Instruction Router

| Domain | File | Use When |
| --- | --- | --- |
| All shell scripts | `.github/instructions/shell-conventions.instructions.md` | Writing or reviewing any `.sh` file |
| `lib/ai-cli/` | `.github/instructions/ai-cli.instructions.md` | Working on AI CLI installers |
| `lib/aws/` | `.github/instructions/aws.instructions.md` | Working on AWS scripts |
| `lib/stacks/` | `.github/instructions/stacks.instructions.md` | Working on stack scripts |
| Standalone domains | `.github/instructions/dev.instructions.md` | Working on `workflow/`, `docker/`, `health/`, `maintenance/`, `tools/`, or `codegen/` scripts |

## Shared Helpers and Logging

- `lib/ai-cli/` sources `_common.sh` from the same directory.
- `lib/stacks/` sources `../_common.sh` from subdirectories.
- `lib/aws/` sources `_aws-common.sh` from the same directory.
- Logging is domain-scoped:
  - `ai-cli`: direct coloured output
  - `stacks`: `step`/`pass`/`fail` helpers
  - standalone domains: inline `log`/`success`/`warn`/`error` helpers or close variants

Read `docs/footguns.md` before changing any of these patterns.

## Template and Output Contracts

### Changing a template script

- Treat the `# ---- CONFIGURATION ----` block as a public interface.
- Do not replace placeholder defaults like `my-project` or `us-east-1` unless you are intentionally changing the template contract.
- If the template interface changes, update help text and verify sibling templates still use the same pattern.

### Changing output consumed by the dashboard

- Read the shell producer and the PHP consumer before editing headings, table shapes, or summary rows.
- AWS cost output is parsed by `dashboard/aws_ui.php`; report-heading changes can break the dashboard without touching PHP.
- Prefer machine-readable output when the coupling becomes brittle.

## Repo Entrypoints

- `help.sh` delegates to `lib/workflow/help-index.sh` and is the root script index.
- `preflight-checks.sh` is the repo-level quality gate for `lib/**/*.sh`.
- `scripts/preflight-checks.sh` is the Codex workflow wrapper that adds context validation and non-`lib/` checks.
- `dashboard/start-dev.sh` launches the PHP dashboard and is an Ask First boundary because it changes the browser entrypoint.

## Commit Format

Use short, imperative subjects such as `add docker restart wrapper`. Keep commits scoped to one script or one coherent workflow. Never commit credentials.
