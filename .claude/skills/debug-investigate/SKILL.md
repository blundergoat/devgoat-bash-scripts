# /debug-investigate - Diagnosis-First Shell Debugging

Use this when a shell script is failing, behaviour is inconsistent, or the root cause is unknown.

## Hard Gate

**If you want to "just try something" before tracing the execution path, STOP.**

Do not propose or apply fixes until the diagnosis is written and the human reviews it.

## Workflow

1. Read the entry script end-to-end. Identify the failing path before touching code.
2. Trace the execution path across source chains:
   - entry script -> sourced helper -> caller-specific function
   - `_common.sh` or `_aws-common.sh` exports, defaults, and helper calls
   - pipes, command substitutions, subshells, and conditional branches
3. Track variable propagation:
   - where variables are set
   - where they are exported
   - where they are consumed after sourcing another file
4. Check exit-code handling carefully:
   - `set -e` interactions with pipes and subshells
   - command substitutions masking failures
   - `||` fallback paths and intentional non-zero returns
5. Check shell-specific hazards:
   - quoting and word splitting
   - glob expansion
   - array vs string assumptions
   - platform differences: WSL vs native bash vs Git Bash
6. Verify helper-source patterns:
   - `lib/ai-cli/` uses same-directory `_common.sh`
   - `lib/stacks/` uses parent traversal `../_common.sh`
   - these are NOT interchangeable
7. Check `docs/footguns.md` for matching traps before concluding.

## Diagnosis Output Template

```md
## Diagnosis

**Symptom:** what the user observed
**Entry script:** `script:line`
**Execution path:** `script:line` -> `script:line` -> `script:line`
**Variable flow:** where key variables are set, exported, and consumed
**Exit-code path:** where failure is triggered, masked, or propagated
**Evidence:** `script:line` references that prove the diagnosis
**Platform notes:** WSL / native bash / Git Bash differences, if relevant
**Related footguns:** matching entries from docs/footguns.md, if any
**Blast radius:** what else could be affected
```

## Special Attention

- `set -e` behaviour around pipes, subshells, and command substitutions
- variable scope across `source` boundaries
- quoting problems that only fail with spaces or globs
- platform-specific command resolution
- shared helper changes that affect multiple domains

## After Review

Once the human approves the diagnosis, propose the minimal fix and verify it with:
- `bash -n`
- `shellcheck`
- `bats tests/ --recursive`

If two fix attempts fail, stop and report what was tried and why it failed.
