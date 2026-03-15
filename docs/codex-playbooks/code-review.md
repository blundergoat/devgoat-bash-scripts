# Code Review Playbook

Use this when the user asks for a review or when a change needs a structured risk pass.

## Findings Order

- `P0` data loss, security, or destructive workflow risk
- `P1` behavioural regression or broken contract
- `P2` test gap, maintainability risk, or fragile coupling

## Review Checklist

- Read the diff and the adjacent consumers.
- Verify changed code against existing conventions in the same domain.
- Check Ask First boundaries from `AGENTS.md` before treating a risky change as acceptable.
- Look for missing verification, stale references after renames, and broken dashboard/report couplings.

## Output

- Findings first, with file:line references
- Open questions or assumptions second
- Short summary last
