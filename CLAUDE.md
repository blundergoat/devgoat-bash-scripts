# CLAUDE.md — v2.1 (2026-03-20)

Shell script library. Drop-in or template scripts under `lib/`. Bats test suite under `tests/`.

## Essential Commands

```bash
bash -n path/to/script.sh            # Syntax-check
shellcheck path/to/script.sh         # Lint
bats tests/ --recursive              # Run test suite
./preflight-checks.sh                # Quality gate
```

## Execution Loop: READ → CLASSIFY → SCOPE → ACT → VERIFY → LOG

**READ** — MUST read relevant files before changes. Cross-domain: MUST read both sides.
```
❌ "The _common.sh uses parent traversal" (guessed)
✅ Read lib/stacks/_common.sh → confirmed: source "../_common.sh"
```
**CLASSIFY** — MUST declare complexity and mode before acting.
Complexity: Hotfix (2 reads / 3 turns) | Standard (4 / 10) | System Change (6 / 20) | Infra (8 / 25). Over budget = re-classify.
Mode: Plan / Implement / Explain / Debug / Review. Question = answer; directive = act. MUST NOT infer implementation from a question.

**SCOPE** — MUST declare before acting: files to change, non-goals, max blast radius. Expanding = stop and re-scope.

**ACT** — MUST declare: `State: [MODE] | Goal: [one line] | Exit: [condition]`
No actions outside declared state without: "Switching to [NEW STATE] because [reason]."

| Mode | Behaviour |
|------|-----------|
| Plan | Produce artefact only. No app code. Exit on LGTM |
| Implement | Code in 2-3 turns. 4th read without writing = stop |
| Explain | Walkthrough only. No code changes unless asked |
| Debug | Diagnosis with file:line first. Fixes after human reviews |
| Review | Investigate first. Never blindly apply suggestions |

```
❌ Created abstract logging base class (one implementation)
✅ Inline functions. Extract when second consumer appears
```
**VERIFY** — MUST run after each change: `bash -n` → `shellcheck` → `bats tests/ --recursive`
- Level 1 (isolated failure): note, continue
- Level 2 (cross-domain/security): MUST full stop, diagnosis with file:line, wait for human
- Two corrections on same approach = MUST rewind

**LOG** — MUST update when tripped (DoD gate #4). SHOULD load `docs/footguns.md` at Ask First boundaries.

| File | When |
|------|------|
| `docs/lessons.md` | Behavioural mistake (agent did wrong) |
| `docs/footguns.md` | Cross-domain landmine (file:line evidence) |
| `docs/confusion-log.md` | Structural confusion (hard to navigate) |

Mechanical trigger: if VERIFY caught a failure in your code, or you corrected course, lessons.md entry required before DoD satisfied. After human correction, MUST log immediately.
Dual-agent: read learning loop files before appending to avoid duplicating entries from Codex.
Propagate footguns as one-line summaries to relevant local CLAUDE.md.

## Autonomy Tiers

**Always:** Run tests/lint, read any file, write scripts, append to log files

**Ask First** (MUST: boundary named, related code read, footgun checked, local CLAUDE.md checked, rollback command):
- `_common.sh` / `_aws-common.sh` changes (sourced by many scripts)
- CONFIGURATION block interface changes (adding/removing variables)
- Scripts in `lib/ai-cli/` that sanitise WSL PATH
- Adding new domains/directories under `lib/`
- Changing a script's logging paradigm (MUST match siblings)
- Editing `.github/instructions/` files
- Cross-domain changes. Strict mode exception changes

**Never:** Delete tests to pass builds. Modify .env/secrets. Push to main. Force push. Change CONFIGURATION block values. Commit unless asked. Modify lockfiles or generated code

## Definition of Done

MUST confirm ALL: (1) `bash -n` + `shellcheck` pass (2) `bats tests/` green (3) no unapproved boundary changes (4) logs updated if tripped (5) working notes current (6) grep old pattern after renames

## Hard Rules

- MUST use `#!/usr/bin/env bash` + `set -euo pipefail` (exceptions: `docs/footguns.md`)
- MUST match sibling logging paradigm (`docs/domain-reference.md`)
- MUST use short imperative commits. One per script. Never commit credentials
- MUST append cross-domain bugs to `docs/footguns.md` before closing

Sub-agents: ONE focused objective, structured return (paths, evidence, confidence, next step), 5-call budget.
When blocked: ask exactly one question with a recommended default.

## Working Memory

SHOULD use `tasks/todo.md` for 5+ turn tasks. SHOULD write `tasks/handoff.md` before ending incomplete work. Context escalation: `/compact` after 15+ turns → split if two compactions → `/clear` between unrelated tasks.

## Router Table

| Resource | Path |
|----------|------|
| Domain reference | `docs/domain-reference.md` |
| Architecture | `docs/architecture.md` |
| Code map | `docs/code-map.md` |
| Bats guide | `docs/bats-core.md` |
| Footguns | `docs/footguns.md` |
| Lessons | `docs/lessons.md` |
| Confusion log | `docs/confusion-log.md` |
| Shell conventions | `.github/instructions/shell-conventions.instructions.md` |
| Domain instructions | `.github/instructions/{ai-cli,aws,stacks,dev}.instructions.md` |
| Preflight skill | `.claude/skills/goat-preflight/` |
| Review skill | `.claude/skills/goat-review/` |
| Debug skill | `.claude/skills/goat-debug/` |
| Audit skill | `.claude/skills/goat-audit/` |
| Research skill | `.claude/skills/goat-research/` |
| Agent evals | `agent-evals/` |
| Handoff template | `tasks/handoff-template.md` |
| Codex runtime | `AGENTS.md` |
| Codex evals | `codex-evals/` |
