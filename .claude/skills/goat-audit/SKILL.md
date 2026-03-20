# /goat-audit - Four-Pass Shell Audit

Use this for structured audits of scripts, directories, or workflow changes.

## Rules

- Run all four passes in order.
- Every finding must cite `script:line` evidence.
- **MUST NOT propose fixes.** Audit first; remediation only if the human asks later.

## Pass 1: Discovery

Scan the target scripts and log candidate findings with `script:line` evidence.

Audit for:
- unquoted variables in dangerous contexts
- missing error handling around external commands
- hardcoded paths
- secret exposure or credential leakage
- unsafe patterns such as `eval` or unvalidated input
- missing strict mode, unless explicitly documented as an exception
- inconsistent logging paradigm compared with sibling scripts
- helper-source pattern mismatches

## Pass 2: Verification

Re-read each finding in context and confirm it is real.

- read surrounding functions, not just the flagged line
- check whether the pattern is intentional
- remove false positives
- check `docs/footguns.md` for documented exceptions

## Pass 3: Severity Ranking

Rank verified findings in this order:
- `Security`
- `Correctness`
- `Portability`
- `Style`

Use the highest applicable severity. Do not inflate lower-risk findings.

## Pass 4: Fabrication Gate

For every remaining finding, ask:
- did I fabricate this?
- did I verify it against actual code?
- did I skip a conflicting file or exception?

Remove anything that fails this check.

## Output Format

```md
## Audit: [target]

### Security
- `script:line` finding and evidence

### Correctness
- `script:line` finding and evidence

### Portability
- `script:line` finding and evidence

### Style
- `script:line` finding and evidence

### Removed During Verification
- finding removed and why
```
