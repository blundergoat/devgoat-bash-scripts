# AGENTS.md - v2.0 (2026-03-20)

Runtime instructions for Codex. Domain reference: `docs/domain-reference.md`. Ownership split: `docs/guidelines-ownership-split.md`.

## Project Identity

Shell script collection under `lib/`, PHP dashboard in `dashboard/`, bats tests in `tests/`. Scripts are drop-in helpers or templates with `# ---- CONFIGURATION ----` blocks.

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

## Execution Loop: READ → CLASSIFY → SCOPE → ACT → VERIFY → LOG

### READ

- Read relevant files before acting. Cross-domain: read both producer and consumer.
- Never fabricate repo facts. If you have not read it, say so.

```text
BAD: "The dashboard parser is isolated to PHP."
GOOD: Read lib/aws/aws-costs.sh and dashboard/aws_ui.php before changing report headings.
```

### CLASSIFY

Complexity: Hotfix (2 reads / 3 turns) | Standard (4 / 10) | System Change (6 / 20) | Infra (8 / 25). Over budget = re-classify.
Mode: `Answer`, `Plan`, `Implement`, `Debug`, or `Review`. Question = answer; directive = implement. If ambiguous, ask once.

### SCOPE

MUST declare before acting: files to change, non-goals, max blast radius. Expanding beyond scope = stop and re-scope with the human.

### ACT

| Mode | Behaviour |
| --- | --- |
| `Answer` | Explain, report, or compare. No code changes. |
| `Plan` | Produce the plan or research artefact only. No implementation until asked. |
| `Implement` | Make the smallest defensible change. 4th read without writing = stop exploring. |
| `Debug` | Diagnose first, with file:line evidence. Do not patch first and hope. |
| `Review` | Findings first: bugs, risks, regressions, missing tests. Summary second. |

No actions outside declared state without: "Switching to [NEW STATE] because [reason]."

```text
BAD: "I created a shared parser abstraction" for one dashboard report.
GOOD: Patch the existing parser. Extract only when a second consumer appears.
```

### VERIFY

- Run relevant checks after meaningful changes.
- Isolated failure: note, continue. Cross-boundary/unknown blast radius: stop and report diagnosis.
- Two failed approaches: stop and report. After renames: `rg` old pattern, confirm zero stale references.

### LOG

MUST update when tripped (DoD gate #4). SHOULD update after routine sessions.

| File | When |
| --- | --- |
| `docs/lessons.md` | Behavioural mistake (agent did wrong) |
| `docs/footguns.md` | Cross-domain landmine (file:line evidence) |
| `docs/confusion-log.md` | Structural confusion (hard to navigate) |

Mechanical trigger: if VERIFY caught a failure in your code, or you corrected course, lessons.md entry required. After human correction, MUST log immediately. Dual-agent: read learning loop files before appending.
Use `tasks/todo.md` as task scratchpad. `tasks/handoff.md` for incomplete work.

## Autonomy Tiers

### Always

Read first, then act. Match domain helper sourcing, logging style, and verification pattern. Preserve CONFIGURATION block placeholders.

### Ask First

- Shared helpers: `lib/ai-cli/_common.sh`, `lib/stacks/_common.sh`, `lib/aws/_aws-common.sh`
- Any change to a `# ---- CONFIGURATION ----` interface or default
- Strict-mode changes between `set -euo pipefail` and `set -uo pipefail`
- Repo entrypoints: `help.sh`, `preflight-checks.sh`, `dashboard/start-dev.sh`
- Shell output consumed by the dashboard, or generated artefacts like `docs/code-map.md`
- New top-level directories, CI workflow changes, dependency/tooling changes

Checklist: state boundary + files, name downstream consumers, say what will be verified, wait for approval.

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

| Topic | Path |
| --- | --- |
| Architecture | `docs/architecture.md` |
| Domain reference | `docs/domain-reference.md` |
| Ownership split | `docs/guidelines-ownership-split.md` |
| Footguns | `docs/footguns.md` |
| Lessons | `docs/lessons.md` |
| Confusion log | `docs/confusion-log.md` |
| Preflight playbook | `docs/codex-playbooks/preflight.md` |
| Research playbook | `docs/codex-playbooks/research.md` |
| Debug playbook | `docs/codex-playbooks/debug-investigate.md` |
| Audit playbook | `docs/codex-playbooks/audit.md` |
| Code review playbook | `docs/codex-playbooks/code-review.md` |
| Verification scripts | `scripts/context-validate.sh`, `deny-dangerous.sh`, `preflight-checks.sh` |
| Task files | `tasks/todo.md`, `tasks/handoff.md` |
| Claude runtime | `CLAUDE.md` |
| Claude evals | `agent-evals/` |
| Codex evals | `codex-evals/` |
