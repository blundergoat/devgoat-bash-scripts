# Preflight Playbook

Use this when code changed, verification scope is unclear, or a task crossed multiple directories.

## MUST

- Re-read the changed files and the nearest consumer before choosing checks.
- Run the strongest relevant mechanical gate. In this repo, prefer `./scripts/preflight-checks.sh` for cross-domain work.
- Run stack-native lint, syntax, build, or type checks when the touched stack has them.
- Run a dependency audit step when a package manager exists; if none exists, say so explicitly.
- After renames or moves, run `rg` for the old name and report zero remaining references.

## SHOULD

- Run the full bats suite even if a narrower smoke test passed.
- Run formatter or generator steps when the touched file is tool-generated.
- Exercise at least one safe user-facing path, such as `--help`, `--dry-run`, or a read-only report command.

## MAY

- Add extra smoke tests for adjacent scripts or dashboard surfaces.
- Capture command output snippets when they make the verification story clearer.

## Output

- Checks run
- Results
- Known gaps
