# /goat-research — Deep Research for Shell Script Collections

Use this when the human wants understanding before planning or implementation.

## Hard Gate
**NO PLANNING or IMPLEMENTATION until human reviews research.**

## Instructions

### Minimum Template
Produce a research artefact (e.g., `research.md` or a structured response) with the following sections:

1. **Files Involved**
   - Entry scripts, sourced dependencies (`_common.sh`, etc.), and consumers (tests, docs, dashboard).

2. **Request Flow**
   - Trace the execution path from entry point through sourced files.
   - Note where variables are set/consumed and where control flow changes (pipes, subshells).

3. **Boundaries Touched**
   - Identify `lib/` domains and shared helper files involved.
   - Note cross-domain dependencies and public script interfaces (CONFIGURATION blocks).

4. **Risks / Gotchas**
   - **MUST provide at least 3 concrete risks.**
   - **Each risk MUST include `file:line` evidence.**
   - Focus on cross-domain dependencies and logging consistency.

### Research Standard
- Read real files; never fabricate codebase facts.
- Distinguish observed facts from inference.
- Load `docs/footguns.md` when boundaries or shared helpers are involved.

## Output Format
```md
## Files Involved

## Request Flow

## Boundaries Touched

## Risks / Gotchas
- [Risk 1] (file:line)
- [Risk 2] (file:line)
- [Risk 3] (file:line)
```
