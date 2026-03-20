# /goat-debug — Diagnosis-First Shell Debugging

Use this when a shell script is failing, behaviour is inconsistent, or the root cause is unknown.

## Hard Gate
**If you want to "just try something" before tracing the execution path, STOP.**
Do NOT propose or apply fixes until the diagnosis is written and the human reviews it.

## Instructions

### Diagnosis Workflow
1. **Identify the failing path** before touching code. Read entry script end-to-end.
2. **Trace the execution path** across source chains (e.g., entry script -> sourced helper).
3. **Track variable propagation:** Where are variables set, exported, and consumed?
4. **Check exit-code handling:** `set -e` interactions, masked failures in command substitutions.
5. **Check shell-specific hazards:** Quoting, glob expansion, platform differences (WSL vs native).
6. **Verify helper-source patterns:** `lib/ai-cli/` vs `lib/stacks/` sourcing rules.
7. **Check `docs/footguns.md`** for matching traps.

### Diagnosis Standard
- Diagnose first with `file:line` evidence.
- No fixes until human reviews diagnosis.
- If two fix attempts fail, stop and report.

## Output Format
```md
## Diagnosis
**Symptom:** [User observation]
**Entry script:** [file:line]
**Execution path:** [file:line] -> [file:line]
**Variable flow:** [Set/Export/Consume]
**Exit-code path:** [Trigger/Mask/Propagate]
**Evidence:** [file:line references]
**Related footguns:** [entries from docs/footguns.md]
**Blast radius:** [affected components]
```
