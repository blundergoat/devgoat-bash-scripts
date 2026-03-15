# Agent Evals

Regression tests for CLAUDE.md and skill changes. Each `.md` file contains a replay prompt from a real incident.

## How to Use

When you change CLAUDE.md or a skill file:

1. Pick 2-3 evals relevant to the change
2. Run each eval's replay prompt in a fresh Claude Code session
3. Compare the agent's behaviour against the expected outcome
4. If a previously-passing eval now fails → behavioural regression, revert the change

## File Format

Each eval file contains:
- **Origin:** real-history or synthetic-seed
- **Bug description:** what went wrong
- **Replay prompt:** single prompt to paste into Claude Code
- **Expected outcome:** what the agent should do
- **Failure mode tested:** which workflow step this validates
