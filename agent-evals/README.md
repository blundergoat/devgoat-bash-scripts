# Agent Evals

Regression tests for workflow changes. Each `.md` file contains a replay prompt from a real incident. Evals apply to Claude Code, Codex, or both — check the `Agents:` label.

## How to Use

When you change CLAUDE.md, AGENTS.md, a skill, or a playbook:

1. Pick 2-3 evals relevant to the change
2. Run each eval's replay prompt in a fresh session (Claude Code or Codex)
3. Compare the agent's behaviour against the expected outcome
4. If a previously-passing eval now fails → behavioural regression, revert the change

## File Format

Each eval file contains:
- **Origin:** real-incident or synthetic-seed
- **Agents:** all (any agent) or codex / claude (agent-specific)
- **Bug description:** what went wrong
- **Replay prompt:** single prompt to paste into a session
- **Expected outcome:** what the agent should do
- **Failure mode tested:** which workflow step this validates
