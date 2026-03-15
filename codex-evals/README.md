# Codex Evals

Replay fixtures for the Codex-side workflow in `AGENTS.md` and `docs/codex-playbooks/`.

## How To Use

1. Pick 2 or 3 evals that match the workflow surface you changed.
2. Run each replay prompt in a fresh Codex task.
3. Compare the behaviour against the expected outcome.
4. Treat a previously passing eval that now fails as a workflow regression.

## File Format

Each eval records:
- `Origin`
- `Bug description`
- `Replay prompt`
- `Expected outcome`
- `Failure mode tested`
