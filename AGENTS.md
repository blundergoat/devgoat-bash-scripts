# AGENTS.md - v1.0 (2026-03-15)

Runtime instructions for Codex in `devgoat-bash-scripts`. Repo-specific engineering patterns that used to live here now live in `docs/domain-reference.md`. The ownership split is recorded in `docs/guidelines-ownership-split.md`.

## Project Identity

This repo is a collection of reusable shell scripts organised by domain under `lib/`, plus a PHP dashboard in `dashboard/` and bats tests in `tests/`. Scripts are either drop-in helpers or templates with a `# ---- CONFIGURATION ----` block.

## Essential Commands

```bash
bash -n path/to/script.sh
shellcheck path/to/script.sh
php -l dashboard/aws_ui.php
./help.sh
./preflight-checks.sh
./scripts/context-validate.sh
./scripts/deny-dangerous.sh --self-test
./scripts/preflight-checks.sh
bats tests/ --recursive
./lib/codegen/generate-code-map.sh
```

## Default Loop

### READ

- Read the relevant files before acting. For cross-domain work, read both the producer and the consumer.
- Never fabricate repo facts. If you have not read it, say so.

```text
BAD: "The dashboard parser is isolated to PHP."
GOOD: Read lib/aws/aws-costs.sh and dashboard/aws_ui.php before changing report headings.
```

### CLASSIFY

- State mode and complexity before substantial work: `Answer`, `Plan`, `Implement`, `Debug`, or `Review`; `Hotfix`, `Standard`, `System`, or `Infra`.
- Questions get answers, not edits. Directives get implementation. If intent is ambiguous, ask once.
- State mode changes explicitly; do not drift from explanation into implementation.

### ACT

| Mode | Behaviour |
| --- | --- |
| `Answer` | Explain, report, or compare. No code changes. |
| `Plan` | Produce the plan or research artefact only. No implementation until asked. |
| `Implement` | Make the smallest defensible change after reading the code. Do not stop at a speculative plan unless blocked. |
| `Debug` | Diagnose first, with file:line evidence. Do not patch first and hope. |
| `Review` | Findings first: bugs, risks, regressions, missing tests. Summary second. |

Anti-planning-loop: if the user asked for a fix and the path is clear after reading, implement it.

```text
BAD: "I created a shared parser abstraction" for one dashboard report.
GOOD: Patch the existing parser. Extract only when a second consumer appears.
```

### VERIFY

- Run relevant checks after meaningful changes.
- Isolated failure: note it, finish safe work, and report the gap.
- Cross-boundary regression or unknown blast radius: stop and report the diagnosis before pushing further.
- Two failed approaches on the same fix: stop and report what failed and why.
- After renames or moves, `rg` for the old pattern and confirm zero stale references.

### RECORD

- Update `docs/footguns.md` when you hit a real cross-domain landmine with verified evidence.
- Update `docs/lessons.md` for repeatable agent-behaviour mistakes.
- Use `tasks/todo.md` as the task scratchpad and `tasks/handoff.md` when work stops mid-task.
- Load router targets on demand. Keep context tight.

## Autonomy Tiers

### Always

- Read first, then act.
- Preserve template placeholders inside `# ---- CONFIGURATION ----` blocks unless the interface itself is being changed.
- Match the touched domain's helper sourcing, logging style, and verification pattern.

### Ask First

- Shared helpers: `lib/ai-cli/_common.sh`, `lib/stacks/_common.sh`, `lib/aws/_aws-common.sh`
- Any change to a `# ---- CONFIGURATION ----` interface or default
- Strict-mode changes between `set -euo pipefail` and `set -uo pipefail`
- Repo entrypoints: `help.sh`, `preflight-checks.sh`, `dashboard/start-dev.sh`
- Shell output consumed by the dashboard, or generated artefacts like `docs/code-map.md`
- New top-level directories, CI workflow changes, dependency/tooling changes

Ask First checklist:
- State the files and boundary being crossed.
- Name the downstream consumers or users.
- Say what will be verified after the change.
- Wait for approval before editing.

### Never

- Delete tests to make checks pass.
- Edit `.env`, secrets, or credentials.
- Commit or push unless explicitly asked; never use `--no-verify`.
- Use destructive git operations or unscoped `rm -rf`.
- Hand-edit generated `docs/code-map.md`.

## Definition of Done

1. Relevant lint, syntax, test, and smoke checks passed, or a concrete gap is reported.
2. User-visible behaviour is verified from the changed path, not assumed.
3. No Ask First boundary was crossed without approval.
4. `docs/footguns.md` or `docs/lessons.md` was updated if the task tripped one.
5. `tasks/todo.md` and `tasks/handoff.md` reflect the current state of the task.
6. After renames or moves, `rg` confirmed no stale references to the old name.

## Router

| Topic | Path | Use When |
| --- | --- | --- |
| Architecture | `docs/architecture.md` | Repo shape, data flows, constraints |
| Domain reference | `docs/domain-reference.md` | Shell patterns, workflows, entrypoints |
| Ownership split | `docs/guidelines-ownership-split.md` | Why AGENTS was trimmed and what moved |
| Lessons log | `docs/lessons.md` | Behavioural mistakes worth retaining |
| Footguns log | `docs/footguns.md` | Cross-domain traps and evidence |
| Task scratchpad | `tasks/todo.md` | Working notes during a task |
| Handoff file | `tasks/handoff.md` | Incomplete-task handoff |
| Preflight playbook | `docs/codex-playbooks/preflight.md` | Picking the right checks |
| Research playbook | `docs/codex-playbooks/research.md` | Deep-read, no-code investigations |
| Debug playbook | `docs/codex-playbooks/debug-investigate.md` | Diagnosis-first debugging |
| Audit playbook | `docs/codex-playbooks/audit.md` | Repo/process audits |
| Code review playbook | `docs/codex-playbooks/code-review.md` | Structured review work |
| Context validator | `scripts/context-validate.sh` | Validate workflow files and router targets |
| Deny policy | `scripts/deny-dangerous.sh` | Review blocked commands and self-tests |
| Workflow preflight | `scripts/preflight-checks.sh` | Run the Codex verification suite |
| Claude runtime | `CLAUDE.md` | Compare the Claude-side implementation |
| Claude evals | `agent-evals/README.md` | Existing Claude replay fixtures |
| Codex evals | `codex-evals/README.md` | Codex replay fixtures |
