# CLAUDE.md — v2.2 (2026-03-21)

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
BAD:  "The _common.sh uses parent traversal" (guessed without reading)
GOOD: Read lib/stacks/_common.sh:7 → confirmed: source "../_common.sh"
```
**CLASSIFY** — MUST declare 3 signals before acting:
(1) Intent: question = answer; directive = act. MUST NOT infer implementation. (2) Complexity: Hotfix (2/3) | Standard (4/10) | System (6/20) | Infra (8/25). Over budget = re-classify. (3) Mode: Plan / Implement / Explain / Debug / Review.

**SCOPE** — MUST declare before acting: files to change, non-goals, max blast radius. Expanding = stop and re-scope.

**ACT** — MUST declare: `State: [MODE] | Goal: [one line] | Exit: [condition]`
No actions outside declared state without: "Switching to [NEW STATE] because [reason]."

| Mode | Behaviour |
|------|-----------|
| Plan | Produce artefact only. No app code. Exit on LGTM |
| Implement | Code in 2-3 turns. 4th read without writing = stop |
| Explain | Walkthrough only. No code changes unless asked |
| Debug | Diagnosis with file:line first. No fixes until human reviews diagnosis |
| Review | Investigate first. Never blindly apply suggestions |

```
BAD:  Created abstract logging base class (one implementation exists)
GOOD: Inline helpers. Extract when second consumer appears
```
**VERIFY** — MUST run after each change: `bash -n` → `shellcheck` → `bats tests/ --recursive`
- Level 1 (isolated failure): note, continue. Level 2 (cross-domain/security): MUST full stop, diagnosis with file:line, wait for human
- Two corrections on same approach = MUST rewind
Recovery: missing context → read first. Out-of-scope → name boundary, redirect. Conflicting instructions → flag, ask.

**LOG** — MUST update when tripped (DoD gate #4). SHOULD load `docs/footguns.md` at Ask First boundaries.

| File | When |
|------|------|
| `docs/lessons.md` | Behavioural mistake (agent did wrong) |
| `docs/footguns.md` | Cross-domain landmine (file:line evidence) |
| `docs/decisions/` | Significant technical decision (context + rationale) |

Mechanical trigger: if VERIFY caught a failure in your code, or you corrected course, lessons.md entry required before DoD satisfied. After human correction, MUST log immediately.
Dual-agent: read learning loop files before appending to avoid duplicating entries from Codex.
Propagate footguns as one-line summaries to relevant local CLAUDE.md.

## Autonomy Tiers

**Always:** Run tests/lint, read any file, write scripts, append to log files

**Ask First** (project-specific boundaries for `lib/`, `lib/aws/`, `lib/stacks/`, `lib/ai-cli/`):
- `lib/stacks/_common.sh` / `lib/ai-cli/_common.sh` / `lib/aws/_aws-common.sh` changes (sourced by many scripts)
- CONFIGURATION block interface changes (adding/removing variables)
- Scripts in `lib/ai-cli/` that sanitise WSL PATH
- Adding new domains/directories under `lib/`
- Changing a script's logging paradigm (MUST match siblings)
- Editing `ai/instructions/` or `.github/instructions/` files
- Cross-domain changes. Strict mode exception changes
Checklist:
1. Boundary touched: [name]
2. Related code read: [yes/no]
3. Footgun entry checked: [relevant entry, or "none"]
4. Local instruction checked: [local CLAUDE.md / .github/instructions/ / none]
5. Rollback command: [exact command]

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

When sources conflict: (1) user's explicit instruction > (2) CLAUDE.md > (3) setup templates > (4) system spec > (5) skills/playbooks.

## Router Table

| Resource | Path |
|----------|------|
| Docs | `docs/domain-reference.md`, `docs/architecture.md`, `docs/code-map.md`, `docs/bats-core.md` |
| Footguns | `docs/footguns.md` |
| Lessons | `docs/lessons.md` |
| Decisions | `docs/decisions/` |
| Instructions | `ai/instructions/`, `.github/instructions/` |
| Investigate skill | `.claude/skills/goat-investigate/` |
| Debug skill | `.claude/skills/goat-debug/` |
| Audit skill | `.claude/skills/goat-audit/` |
| Review skill | `.claude/skills/goat-review/` |
| Plan skill | `.claude/skills/goat-plan/` |
| Test skill | `.claude/skills/goat-test/` |
| Agent evals | `agent-evals/` |
| Handoff template | `tasks/handoff-template.md` |
| Codex runtime | `AGENTS.md` |
