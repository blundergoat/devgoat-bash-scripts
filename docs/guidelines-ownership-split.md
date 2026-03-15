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
