# CLAUDE.md — v1.0 (2026-03-15)

Shell script library. Drop-in or template scripts under `lib/`. Bats test suite under `tests/`.

## Essential Commands

```bash
bash -n path/to/script.sh            # Syntax-check
shellcheck path/to/script.sh         # Lint
bats tests/ --recursive              # Run test suite
./preflight-checks.sh                # Quality gate
```

## Execution Loop: READ → CLASSIFY → ACT → VERIFY → LOG

**READ** — MUST read relevant files before changes. Cross-domain: MUST read both sides.
```
❌ "The _common.sh uses parent traversal" (guessed)
✅ Read lib/stacks/_common.sh → confirmed: source "../_common.sh"
```

**CLASSIFY** — MUST declare mode (Plan/Implement/Explain/Debug/Review) before acting. Question = answer it; directive = act on it. MUST NOT infer implementation from a question.

**ACT** — MUST declare: `State: [MODE] | Goal: [one line] | Exit: [condition]`

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

**LOG** — SHOULD append to `docs/lessons.md` (behavioural mistakes) or `docs/footguns.md` (cross-domain traps with file:line evidence). SHOULD load footguns.md when touching Ask First boundaries.

## Autonomy Tiers

**Always:** Run tests/lint, read any file, write scripts, append to log files

**Ask First** (MUST complete micro-checklist: boundary, related code read, footgun checked, rollback command):
- `_common.sh` / `_aws-common.sh` changes (sourced by many scripts)
- CONFIGURATION block interface changes (adding/removing variables)
- Scripts in `lib/ai-cli/` that sanitise WSL PATH
- Adding new domains/directories under `lib/`
- Changing a script's logging paradigm (must match siblings)
- Editing `.github/instructions/` files
- Cross-domain changes. Strict mode exception changes

**Never:** Delete tests to pass builds. Modify .env/secrets. Push to main. Force push. Change CONFIGURATION block values. Commit unless asked

## Definition of Done

MUST confirm ALL: (1) `bash -n` + `shellcheck` pass (2) `bats tests/` green (3) no unapproved boundary changes (4) logs updated if tripped (5) working notes current (6) grep old pattern after renames

## Hard Rules

- MUST use `#!/usr/bin/env bash` + `set -euo pipefail` (exceptions: `docs/footguns.md`)
- MUST match sibling logging paradigm (`docs/domain-reference.md`). `_common.sh` patterns are not interchangeable
- MUST use short imperative commits. One per script. Never commit credentials
- MUST append cross-domain bugs to `docs/footguns.md` before closing

Sub-agents: ONE focused objective, structured return (paths, evidence, confidence, next step), 5-call budget.
When blocked: ask exactly one question with a recommended default. If not blocked, decide and note assumption.

## Working Memory

SHOULD use `tasks/todo.md` for 5+ turn tasks. SHOULD write `tasks/handoff.md` before ending incomplete work. Context escalation: `/compact` after 15+ turns → split if two compactions → `/clear` between unrelated tasks.

## Router Table

| Resource | Path |
|----------|------|
| Domain reference | `docs/domain-reference.md` |
| Architecture | `docs/architecture.md` |
| Code map | `docs/code-map.md` |
| Footguns | `docs/footguns.md` |
| Lessons | `docs/lessons.md` |
| Bats guide | `docs/bats-core.md` |
| Shell conventions | `.github/instructions/shell-conventions.instructions.md` |
| ai-cli domain | `.github/instructions/ai-cli.instructions.md` |
| AWS domain | `.github/instructions/aws.instructions.md` |
| Stacks domain | `.github/instructions/stacks.instructions.md` |
| Standalone domains | `.github/instructions/dev.instructions.md` |
| Preflight skill | `.claude/skills/preflight/` |
| Code review skill | `.claude/skills/code-review/` |
| Debug skill | `.claude/skills/debug-investigate/` |
| Audit skill | `.claude/skills/audit/` |
| Research skill | `.claude/skills/research/` |
| Agent evals | `agent-evals/` |
| Handoff template | `tasks/handoff-template.md` |
