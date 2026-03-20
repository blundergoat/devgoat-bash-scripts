# /goat-investigate - Deep Read for Shell Script Collections

Use this when the human wants understanding before planning or implementation.

## Hard Gate

Produce `research.md` output only.

Do **NOT** proceed to planning or implementation until the human reviews the research and approves the next step.

## Required Sections

### Files Involved

- list the entry scripts
- list sourced dependencies such as `_common.sh` or `_aws-common.sh`
- note tests, docs, or dashboard consumers that shape behaviour

### Execution Flow

- trace the path from the entry point through sourced files
- note where key variables are set vs consumed
- call out pipes, subshells, or command substitutions that change control flow

### Boundaries Touched

- identify which `lib/` domains are involved
- identify which shared helper files are sourced
- call out cross-domain dependencies, if any
- note CONFIGURATION block contracts or public script interfaces

### Risks / Gotchas

- provide at least 3 concrete risks
- each risk must include `script:line` evidence
- pay special attention to:
  - cross-domain dependencies
  - CONFIGURATION block contracts
  - logging paradigm consistency with sibling scripts

## Research Standard

- read the real files before writing
- distinguish observed facts from inference
- prefer execution-path detail over generic summary
- load `docs/footguns.md` when boundaries or shared helpers are involved

## Output Skeleton

```md
## Files Involved

## Execution Flow

## Boundaries Touched

## Risks / Gotchas
```
