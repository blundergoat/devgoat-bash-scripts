# /goat-plan — 4-Phase Planning Workflow

Use this for complex tasks, features, or significant refactors.

## Hard Gate
**Human approval REQUIRED after EACH phase.** Do NOT proceed to the next phase until the human approves the current one.

## Instructions

### 1. Feature Brief (Phase 1)
- **Goal:** Define the "what" and "why."
- **Output:** One-page brief: Problem statement, Proposed solution, Success criteria, Out of scope.
- **Hotfixes:** Compress Phase 1–4 into a single brief.

### 2. Mob Elaboration (Phase 2)
- **Goal:** Explore the "how" with the human.
- **Output:** Brainstorming of 2–3 technical approaches, identifying dependencies and risks.

### 3. SBAO Ranking (Phase 3)
- **Goal:** Compare options using SBAO (Simplicity, Blast Radius, Autonomy, Operability).
- **Standard Features:** Skip this phase (human may opt-in).
- **Large Features:** Rank the approaches from Phase 2.

### 4. Milestones (Phase 4)
- **Goal:** Break the approved approach into executable steps.
- **Output:** 3–5 atomic milestones with verification steps for each.

## Planning Standard
- Load `docs/architecture.md` and `docs/domain-reference.md`.
- Read existing code; never plan for files or symbols that don't exist.
- Identify Ask First boundaries early.

## Output Format
```md
## [Current Phase]

[Phase-specific content]

**Waiting for human approval before proceeding to next phase.**
```
