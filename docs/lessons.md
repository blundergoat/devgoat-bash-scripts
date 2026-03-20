# Lessons

Behavioural mistakes discovered during development. When Codex, Claude, or another assistant makes a repeatable mistake that could recur, append it here.

## Rules

- Keep at most 15 active entries.
- When 3 or more entries share a theme, promote them to a named pattern and archive the individual entries.
- Include a `created_at` date on each entry.
- Review periodically and archive entries that have gone stale.

## Patterns

_(none yet)_

## Entries

### Rename without grep verification

**created_at:** 2026-03-15

When renaming or moving a file, agents skip the grep-for-old-pattern step. This caused stale references in CHANGELOG.md, README.md, help.sh, and docs/code-map.md after `dashboard/start.sh` was renamed to `dashboard/start-dev.sh`. DoD gate #6 exists for this reason: after renames, grep for the old name and fix every reference before declaring done.

**Origin:** agent-evals/rename-grep-verification.md (commit c72338a)
