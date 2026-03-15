# Audit Playbook

Use this for audits of correctness, safety, consistency, or documentation quality.

## Rules

- Read broadly enough to verify each claim.
- MUST NOT propose fixes unless the human asks for them after the audit.
- Prefer findings with file:line evidence over style commentary.

### Discovery

- Enumerate the surfaces inspected.
- Note the assumptions being tested.

### Verification

- Check each candidate finding against the real file, not memory.
- Confirm whether the issue is isolated or systemic.

### Prioritisation

- Order findings by user impact, regression risk, or blast radius.
- Call out missing tests when they hide real risk.

### Self-Check

- Ask: did I fabricate this, overstate this, or skip a conflicting file?
