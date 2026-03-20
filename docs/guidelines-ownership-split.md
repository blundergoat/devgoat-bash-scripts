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

## GOAT Flow v2.1 Migration (2026-03-21)

CLAUDE.md, AGENTS.md, and GEMINI.md upgraded to GOAT Flow system spec v2.1. Changes:

| Change | Before | After | Why |
| --- | --- | --- | --- |
| Execution loop | READ→CLASSIFY→SCOPE→ACT→VERIFY→LOG | Same | Stable |
| Multi-agent | Claude/Codex | Claude/Codex/Gemini | Triple-agent support |
| LOG section | Shared files | Explicit dual/triple-agent coordination rules | Prevent log duplication across agents |
| Skills | `.claude/skills/` | `.gemini/skills/` and `.claude/skills/` | Agent-native skill directories |
| Router | Partial | Full cross-agent instructions (CLAUDE.md/AGENTS.md/GEMINI.md) | Visibility for coordinated changes |

## Result

- `CLAUDE.md` owns runtime for Claude Code.
- `AGENTS.md` owns runtime for OpenAI Codex.
- `GEMINI.md` owns runtime for Gemini CLI.
- `docs/domain-reference.md` remains the central hub for repo mechanics.
