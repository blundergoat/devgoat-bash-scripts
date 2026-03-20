# GOAT Preflight

Use this when code changed, verification scope is unclear, or a task crossed multiple directories.

## MUST

- Re-read the changed files and the nearest consumer before choosing checks.
- Run the strongest relevant mechanical gate. In this repo, prefer `./scripts/preflight-checks.sh` for cross-domain work.
- Run stack-native lint, syntax, build, or type checks when the touched stack has them.
- State when dependency audit is not applicable because the repo has no package manager workflow.
- After renames or moves, run `rg` for the old name and report zero remaining references.

## SHOULD

- Run the full bats suite even if a narrower smoke test passed.
- Exercise at least one safe user-facing path such as `--help`, `--dry-run`, or a read-only report command.
- Capture short command evidence when it clarifies the verification story.

## MAY

- Add adjacent smoke tests when the blast radius is uncertain.
- Run generator or formatter steps when the touched file is tool-generated.

## Output

- Checks run
- Results
- Known gaps
