# GEMINI.md - v2.1 (2026-03-21)

Runtime instructions for Gemini CLI. Domain reference: `docs/domain-reference.md`. Ownership split: `docs/guidelines-ownership-split.md`.

## Project Identity
Shell script collection under `lib/`, PHP dashboard in `dashboard/`, bats tests in `tests/`. Scripts are drop-in helpers or templates with `# ---- CONFIGURATION ----` blocks.

## Essential Commands
```bash
bash -n path/to/script.sh                            # Syntax check
shellcheck path/to/script.sh                         # Lint
php -l dashboard/aws_ui.php                          # PHP lint
./help.sh                                            # Script index
./preflight-checks.sh                                # Quality gate
./scripts/preflight-checks.sh                        # Workflow preflight
bats tests/ --recursive                              # Run tests
./lib/maintenance/make-scripts-executable.sh         # Restore chmod +x
./lib/codegen/generate-code-map.sh                   # Inspect structure
```

## Execution Loop: READ → CLASSIFY → SCOPE → ACT → VERIFY → LOG

### READ
- MUST read relevant files before acting. Cross-domain: read producer and consumer.
- MUST NOT fabricate repo facts. If you haven't read it, say so.
- GOOD: Read `lib/aws/aws-costs.sh` and `dashboard/aws_ui.php` before changing report headings.

### CLASSIFY
| Aspect | Rule |
| --- | --- |
| Complexity | MUST follow budgets: Hotfix (2 reads / 3 turns) \| Standard (4 / 10) \| System Change (6 / 20) \| Infrastructure (8 / 25). |
| Mode | MUST use `Answer`, `Plan`, `Implement`, `Debug`, or `Review`. Question = answer; directive = implement. |

### SCOPE
MUST declare before acting: files to change, non-goals, max blast radius. Expanding beyond scope = stop and re-scope.

### ACT
| Mode | Behaviour |
| --- | --- |
| `Answer` | Explain or compare. No code changes. |
| `Plan` | Produce plan or research artefact. No implementation until asked. |
| `Implement` | MUST make smallest defensible change. 4th read without writing = stop and re-scope. |
| `Debug` | MUST diagnose first with file:line. No fixes until human reviews diagnosis. |
| `Review` | Findings first: bugs, risks, regressions. Summary second. |
State: `State: [MODE] | Goal: [one line] | Exit: [condition]`. Explicit transitions: "Switching to [MODE] because [reason]."

### VERIFY
- MUST run relevant checks after changes. Level 1 isolated failure: note and continue. Level 2 cross-boundary: full stop, wait for human.
- Two failed approaches MUST lead to revert-and-rescope. After renames, MUST run `rg` for old pattern.

### LOG
- MUST update when tripped. Reference `docs/lessons.md` (behavioural), `docs/footguns.md` (architectural).
- SHOULD propagate footguns to the nearest routed instruction doc.
- **Dual-Agent:** Learning loop files are shared with Codex (`AGENTS.md`) and Claude (`CLAUDE.md`). MUST read before appending to avoid duplication. After human correction, MUST log immediately.

## Autonomy Tiers

### Always
Read first, then act. Match domain helper sourcing, logging style, and verification pattern. Preserve CONFIGURATION block placeholders.

### Ask First
- MUST ASK before touching: Shared helpers (`lib/ai-cli/_common.sh`, etc.), `# ---- CONFIGURATION ----` changes, Strict-mode changes, Repo entrypoints (`help.sh`, etc.), Dashboard-consumed output, CI changes.
Checklist: 1. Boundary touched [name], 2. Code read [y/n], 3. Footgun checked [entry], 4. Local instruction checked [path], 5. Rollback [cmd].

### Never
- MUST NOT: Delete tests to make checks pass; edit `.env`/secrets; commit/push unless asked; use destructive git/unscoped `rm -rf`; hand-edit `docs/code-map.md`.

## Definition of Done
MUST confirm all 6 gates: 1. Relevant checks passed; 2. Behaviour verified from changed path; 3. No Ask First boundaries crossed without approval; 4. `docs/footguns.md` or `docs/lessons.md` updated if tripped; 5. `tasks/todo.md` and `tasks/handoff.md` updated; 6. `rg` confirmed no stale references after moves.

## Working Memory
- SHOULD use `tasks/todo.md` for 5+ turn work. 
- SHOULD write `tasks/handoff.md` before ending incomplete work. 
- MAY use structural debt trigger to split follow-up tasks.

## Sub-Agent Objectives
Focused objective, structured return (`paths`, `evidence`, `confidence`, `next step`), 5-call budget.

## Communication When Blocked
MAY ask one question, SHOULD include recommended default, then stop.

## Router
| Topic | Path |
| --- | --- |
| Architecture | `docs/architecture.md` |
| Domain reference | `docs/domain-reference.md` |
| Ownership split | `docs/guidelines-ownership-split.md` |
| Footguns / Lessons | `docs/footguns.md` \| `docs/lessons.md` |
| Domain instructions | `.github/instructions/*.instructions.md` |
| Gemini Skills | `.gemini/skills/*/SKILL.md` |
| Codex instructions | `AGENTS.md` |
| Claude instructions | `CLAUDE.md` |
| Verification / Task | `scripts/*.sh` \| `tasks/` |
| Agent evals | `agent-evals/` |
