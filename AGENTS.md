# AGENTS.md - v2.1 (2026-03-21)

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
- MUST read relevant files before acting. Cross-domain: MUST read producer and consumer.
- MUST NOT fabricate repo facts. If you have not read it, say so.

```text
BAD: "The dashboard parser is isolated to PHP."
GOOD: Read lib/aws/aws-costs.sh and dashboard/aws_ui.php before changing report headings.
```

### CLASSIFY
| Aspect | Rule |
| --- | --- |
| Complexity | Hotfix (2 reads / 3 turns) \| Standard (4 / 10) \| System Change (6 / 20) \| Infrastructure (8 / 25). Over budget = re-classify. |
| Mode | `Answer`, `Plan`, `Implement`, `Debug`, or `Review`. Question = answer; directive = implement. If ambiguous, ask once. |

### SCOPE
MUST declare before acting: files to change, non-goals, max blast radius. Expanding beyond scope = stop and re-scope with the human.

### ACT
| Mode | Behaviour |
| --- | --- |
| `Answer` | Explain, report, or compare. No code changes. |
| `Plan` | Produce the plan or research artefact only. No implementation until asked. |
| `Implement` | Make the smallest defensible change. 4th read without writing = stop exploring and start coding or re-scope. |
| `Debug` | Diagnose first with file:line evidence. No fixes until human reviews diagnosis. |
| `Review` | Findings first: bugs, risks, regressions, missing tests. Summary second. |

State: `State: [MODE] | Goal: [one line] | Exit: [condition]`
Mode transitions MUST be explicit: "Switching to [NEW STATE] because [reason]."

```text
BAD: "I created a shared parser abstraction" for one dashboard report.
GOOD: Patch the existing parser. Extract only when a second consumer appears.
```

### VERIFY
- MUST run relevant checks after meaningful changes, not only at the end.
- Level 1 isolated failure: note and continue. Level 2 cross-boundary or unknown blast radius: full stop, diagnose with file:line, wait for the human.
- Two failed approaches = revert-and-rescope. After renames or moves, MUST run `rg` for the old pattern and report zero stale references.

### LOG
MUST update when tripped (DoD gate #4). SHOULD load only the router targets needed for the current task.

| File | When |
| --- | --- |
| `docs/lessons.md` | Behavioural mistake (agent did wrong) |
| `docs/footguns.md` | Cross-domain landmine (file:line evidence) |
Mechanical trigger: if VERIFY caught a failure in code you wrote, or you corrected course, `docs/lessons.md` entry required before DoD satisfied. After human correction, MUST log immediately. Read shared files before appending. Propagate footguns to the nearest routed instruction doc.

## Autonomy Tiers

### Always
Read first, then act. Match domain helper sourcing, logging style, and verification pattern. Preserve CONFIGURATION block placeholders.

### Ask First
- Shared helpers: `lib/ai-cli/_common.sh`, `lib/stacks/_common.sh`, `lib/aws/_aws-common.sh`
- Any `# ---- CONFIGURATION ----` interface or default change
- Strict-mode changes between `set -euo pipefail` and `set -uo pipefail`
- Repo entrypoints: `help.sh`, `preflight-checks.sh`, `dashboard/start-dev.sh`
- Shell output consumed by the dashboard, generated artefacts like `docs/code-map.md`, new top-level directories, CI workflow changes, dependency/tooling changes
Checklist:
1. Boundary touched: [name]
2. Related code read: [yes/no]
3. Footgun entry checked: [relevant entry, or "none"]
4. Local instruction checked: [.github/instructions/<file> / CLAUDE.md / none]
5. Rollback command: [exact command]

### Never
- Delete tests to make checks pass.
- Edit `.env`, secrets, or credentials.
- Commit or push unless explicitly asked; never use `--no-verify`.
- Use destructive git operations or unscoped `rm -rf`.
- Hand-edit generated `docs/code-map.md`.

## Definition of Done
MUST confirm all 6 gates: relevant lint/syntax/test/smoke checks passed or a concrete gap was reported; user-visible behaviour was verified from the changed path; no Ask First boundary was crossed without approval; `docs/footguns.md` or `docs/lessons.md` was updated if tripped; `tasks/todo.md` and `tasks/handoff.md` reflect task state; after renames or moves, `rg` confirmed no stale references.

## Working Memory
SHOULD use `tasks/todo.md` for 5+ turn work. SHOULD write `tasks/handoff.md` before ending incomplete work.
Context ladder: re-read router targets, restate scope, then split a follow-up task with handoff if context is still muddy.

## Sub-Agent Objectives
Sub-agents SHOULD get one focused objective, a structured return (`paths`, `evidence`, `confidence`, `next step`), and a 5-call budget.

## Communication When Blocked
Ask exactly one question, include a recommended default, and stop after the question.

## Router
| Topic | Path |
| --- | --- |
| Architecture | `docs/architecture.md` |
| Domain reference | `docs/domain-reference.md` |
| Ownership split | `docs/guidelines-ownership-split.md` |
| Footguns | `docs/footguns.md` |
| Lessons | `docs/lessons.md` |
| Domain instructions | `.github/instructions/*.instructions.md` |
| Codex preflight | `docs/codex-playbooks/goat-preflight.md` |
| Codex research | `docs/codex-playbooks/goat-research.md` |
| Codex debug | `docs/codex-playbooks/goat-debug.md` |
| Codex audit | `docs/codex-playbooks/goat-audit.md` |
| Codex review | `docs/codex-playbooks/goat-review.md` |
| Verification scripts | `scripts/*.sh` |
| Task notes | `tasks/todo.md` |
| Session handoff | `tasks/handoff.md` |
| Handoff template | `tasks/handoff-template.md` |
| Claude runtime | `CLAUDE.md` |
| Agent evals | `agent-evals/` |
