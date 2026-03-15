# Research Playbook

Use this for deep-read tasks, design investigation, or any request where the human wants understanding before implementation.

## Hard Gate

- No code changes.
- No implementation plan.
- Stop after the research artefact until the human reviews it.

### Files Involved

- List the files read.
- Separate primary files from adjacent context.

### Request Flow

- Trace the path from entrypoint to side effects.
- Name where inputs come from, where decisions happen, and where outputs land.

### Boundaries Touched

- Call out shared helpers, dashboard consumers, templates, generated files, CI, or public interfaces.

### Risks / Gotchas

- Provide at least 3 concrete risks.
- Each risk must cite file:line evidence.
- Prefer repo-specific traps over generic concerns.
