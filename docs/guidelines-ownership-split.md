# Guidelines Ownership Split

This repo started with `AGENTS.md` acting as both a runtime file and a domain reference. The Codex workflow split those responsibilities so the runtime loop stays short and the engineering details stay searchable.

## Before / After Overlap Report

| Previous section in `AGENTS.md` | Action | New home | Why |
| --- | --- | --- | --- |
| `Project Identity` | Kept | `AGENTS.md` | Runtime needs a one-paragraph repo definition. |
| `Essential Commands` | Kept and expanded | `AGENTS.md` | These are high-signal runtime commands Codex should see every task. |
| `Hard Rules` | Split | `AGENTS.md`, `docs/domain-reference.md` | Autonomy boundaries stay in runtime; repo mechanics move to reference docs. |
| `Common Workflows` | Moved | `docs/domain-reference.md` | Domain implementation patterns are reference material, not loop instructions. |
| `Commit Format` | Moved | `docs/domain-reference.md` | Useful project policy, but not part of the execution loop. |
| `Context Router` | Split | `AGENTS.md`, `docs/domain-reference.md` | `AGENTS.md` routes workflow artefacts; `docs/domain-reference.md` routes domain instruction files. |

## What Stayed Out Of Scope

- `.github/instructions/*.md` remains the source of domain-specific engineering guidance.
- Existing Claude workflow files remain in place. This change adds a Codex-native layer instead of deleting the Claude one.

## Result

- `AGENTS.md` now owns the execution loop, autonomy tiers, definition of done, task files, and workflow router.
- `docs/domain-reference.md` owns repo mechanics, common workflows, entrypoint descriptions, and the domain instruction router.
- `docs/guidelines-ownership-split.md` records the migration so future edits do not drift back into overlap.

## GOAT Flow v2.0 Migration (2026-03-20)

CLAUDE.md upgraded to GOAT Flow system spec v0.7. Changes:

| Change | Before | After | Why |
| --- | --- | --- | --- |
| Execution loop | READ→CLASSIFY→ACT→VERIFY→LOG | READ→CLASSIFY→SCOPE→ACT→VERIFY→LOG | SCOPE step prevents silent scope creep |
| CLASSIFY | Mode only | Complexity tiers (Hotfix/Standard/System/Infra) with read/turn budgets | Prevents planning loops and drift |
| Autonomy micro-checklist | 4 items | 5 items (added local CLAUDE.md check) | Layer 2 awareness |
| Never tier | No lockfile/generated rule | Added lockfile + generated code prohibition | Agents hallucinate version bumps |
| LOG section | Two files | Three files (added confusion-log.md) | Structural confusion tracking |
| Skills | preflight, code-review, debug-investigate, audit, research | goat-preflight, goat-review, goat-debug, goat-audit, goat-research | Avoid shadowing built-in commands (AP2) |
| Enforcement | deny-dangerous.sh only | Added lockfile/generated code blocks | Defence in depth |
| Agent ignore | None | .copilotignore, .cursorignore | Prevent secret leakage to other agents |
| CI | Skills + line count | Added router table reference validation | Catch broken references on PR |
| RFC 2119 | Partial | Full pass on CLAUDE.md | Consistent rule strength signalling |

## Codex vs Claude Notes

- Shared-guidelines audit was skipped because this repo uses domain-scoped `.github/instructions/*.instructions.md`, not a shared workflow guidelines file.
- Claude keeps slash-command skills in `.claude/skills/goat-*`; Codex uses document playbooks in `docs/codex-playbooks/goat-*.md`.
- `scripts/deny-dangerous.sh` documents policy and verifies examples, but it is not a runtime blocker or permission deny list. Codex has no equivalent to Claude Code's hook-based enforcement.
