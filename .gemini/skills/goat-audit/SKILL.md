# /goat-audit — Four-Pass Shell Audit

Use this for structured audits of scripts, directories, or workflow changes.

## Rules
- Run all four passes in order.
- Every finding MUST cite `file:line` evidence.
- **MUST NOT propose fixes.** Audit first; remediation only if the human asks later.

## Instructions

### Pass 1: Discovery
Scan target scripts for candidate findings (unquoted variables, missing error handling, hardcoded paths, secret exposure, unsafe patterns, inconsistent logging, helper-source mismatches).

### Pass 2: Verification
Re-read findings in context; check surrounding functions and `docs/footguns.md` for documented exceptions. Confirm if real; remove false positives.

### Pass 3: Prioritisation (Severity Ranking)
Rank verified findings in order:
1. **Security**
2. **Correctness**
3. **Portability**
4. **Style**

### Pass 4: Self-Check (Fabrication Gate)
For every remaining finding, verify against actual code. Remove anything that was fabricated or skips a documented exception.

## Output Format
```md
## Audit: [Target]

### Security
- [file:line] finding and evidence

### Correctness
- [file:line] finding and evidence

### Portability
- [file:line] finding and evidence

### Style
- [file:line] finding and evidence

### Removed During Verification / Self-Check
- [Finding] removed because [reason]
```
