# /goat-plan — Structured Planning Workflow

Use this for features, system changes, or infrastructure work that needs a plan before implementation.

## Complexity Routing

- **Hotfix:** Compress to a single feature brief (phase 1 only). Skip elaboration, SBAO, and milestones.
- **Standard:** Feature brief → mob elaboration → milestones. Skip SBAO ranking.
- **System / Infrastructure:** All 4 phases with Triangular Tension Pass in phase 2.

## Phase 1: Feature Brief

Produce a concise brief: problem statement, proposed approach, scope boundaries, success criteria.

**Human gate:** wait for approval before proceeding.

## Phase 2: Mob Elaboration

Expand the brief into detailed design: components affected, data flows, edge cases, integration points.

### Triangular Tension Pass (System / Infra only)

Three lenses applied in sequence. Each completes before the next begins. Visible disagreement is preserved — do not resolve tension silently.

1. **SKEPTIC** — What could go wrong? Attack assumptions, surface risks, find failure modes.
2. **ANALYST** — What does the evidence say? Trace code paths, verify claims, check constraints.
3. **STRATEGIST** — What is the simplest path that handles the risks? Propose approach with trade-offs stated.

Preserve all three outputs. Conflicts between lenses are valuable — flag them for the human.

**Human gate:** wait for approval before proceeding.

## Phase 3: SBAO Ranking (System / Infra only)

Rank elaborated items by: Severity (impact if wrong), Blast radius (how much breaks), Autonomy (can the agent do it alone?), Order (dependency sequence).

Present the ranked list. Human re-orders or approves.

**Human gate:** wait for approval before proceeding.

## Phase 4: Milestones

Break the plan into implementable milestones. Each milestone must be:
- Independently testable
- Completable in one session
- Ordered by dependency, then by SBAO rank

## Output Format

```md
## Feature Brief
## Elaboration
## SBAO Ranking (if applicable)
## Milestones
```

## Hard Gate

Produce planning artefacts only. Do NOT write application code. Exit on "LGTM" or "implement."
