# GOAT Audit

Use this for audits of correctness, safety, consistency, or documentation quality.

## Pass 1

- Enumerate the surfaces inspected.
- Name the assumptions being tested.

## Pass 2

- Read broadly enough to verify each claim.
- MUST NOT propose fixes unless the human asks after the audit.

## Pass 3

- Order findings by user impact, regression risk, or blast radius.
- Call out missing tests when they hide real risk.

## Pass 4

- Prefer findings with file:line evidence over style commentary.
- Check each candidate finding against the real file, not memory.

## Self-Check

- Ask: did I fabricate this, overstate this, or skip a conflicting file?
