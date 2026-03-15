# Codex Workflow Implementation Prompt

Give this to Codex. Prefer a single session. If the repo is too large for one clean pass, finish the foundation first and report the split explicitly instead of bluffing completeness.

---

## Context Prompt

Paste this first:

```text
I have an AI workflow system designed for Claude Code that I want to adapt
for Codex. The core idea: instead of a wall of rules, give the agent a
5-step execution loop (READ -> CLASSIFY -> ACT -> VERIFY -> RECORD) with
autonomy tiers, a definition of done, and a learning loop.

Read these files for the full system design:
- 00-1-ai-workflow-improvement-plan-prime_v1.3.md
  (the plan - 5-layer architecture; if your copy was renamed, use
  ai-workflow-improvement-plan.md)
- ai-workflow-ARTICLE-prime.md (real implementation data from 3 projects)

Now adapt this system for Codex. NOT a copy - a Codex-native implementation
that respects how Codex actually works. Key differences from Claude Code:

CODEX MECHANICS (respect these):
- AGENTS.md is the root instruction file (not CLAUDE.md)
- No slash commands - use playbook .md files in docs/codex-playbooks/
- No hooks system - use AGENTS.md rules + verification scripts
- apply_patch for edits (not Edit/Write tool)
- Codex may run in cloud sandboxes or local constrained shells depending on client.
  Design for least privilege either way.
- No /compact, no /clear, no /insights - context is per-task
- No .claude/ directory structure
- No settings.json or profiles

WHAT TO BUILD (in this order):

1. AGENTS.md (root runtime file)
   - Keep it concise. Do not fetishize a line count, but keep the runtime
     file short with referenced docs for detail.
   - Default execution loop: READ -> CLASSIFY -> ACT -> VERIFY -> RECORD
     - READ: read relevant files first, never fabricate. Include bad/good example
     - CLASSIFY: declare mode (Answer, Plan, Implement, Debug, Review) +
       complexity. Question vs directive disambiguation. State declaration.
     - ACT: mode-constrained behaviour table. Anti-planning-loop rule.
       Anti-BDUF guard with bad/good example.
     - VERIFY: run tests after meaningful changes. Two-level escalation
       (isolated -> note and continue; cross-boundary -> full stop + diagnosis).
       Two failed approaches on same fix = stop and report.
     - RECORD: docs/lessons.md (behavioural mistakes) + docs/footguns.md
       (architectural landmines). Context-based loading rules.
   - Autonomy tiers: Always / Ask First / Never
     - Adapt Ask First boundaries for THIS project
     - Include micro-checklist for Ask First items
     - Never: delete tests, modify secrets, make commits unless asked,
       no destructive git operations
   - Definition of Done: 6 gates (tests green, verification passes,
     no unapproved boundary changes, logs updated if tripped, notes current,
     grep after renames)
   - Router table: pointers to playbooks, docs, evals
   - Essential commands for this project

   If AGENTS.md already exists:
   - preserve project-specific identity and essential commands
   - preserve any repo-specific safety rules unless they clearly conflict with
     the new ownership split
   - migrate domain reference material (architecture, design patterns,
     conventions) into docs/architecture.md or docs/domain-reference.md
   - report what was moved, what was kept, and why
   - then rebuild the execution loop on top

2. Guidelines ownership split
   - If a coding-standards or guidelines file exists, audit for overlap
   - AGENTS.md owns: execution loop, autonomy tiers, DoD, log files, router
   - Guidelines file owns: engineering practices, coding patterns, testing
     strategy, communication style
   - Remove overlap from guidelines. Before editing, produce a
     before/after overlap report listing every line or section to be removed
     and why. Do not auto-remove without this diff.
   - Do not rewrite unrelated docs or repo policy files outside this ownership split.

3. Docs seed files (create ALL of these - no implied files)
   - docs/lessons.md - format header, empty Entries/Patterns sections
   - docs/footguns.md - read the actual codebase for real cross-domain
     footguns. Seed with real ones only. Include file:line evidence.
   - docs/architecture.md - short overview (under 100 lines): what the
     system does, components, data flows, constraints, trade-offs
   - tasks/todo.md - empty runtime file for working notes during tasks
   - tasks/handoff.md - empty runtime file with handoff template
     (Status, Current State, Key Decisions, Known Risks, Next Step)

4. Codex playbooks (docs/codex-playbooks/)
   Create these as standalone .md files the agent reads on demand:

   - preflight.md - mechanical verification with priority markers.
     MUST: build + lint + type-check when applicable.
     SHOULD: full test suite, formatter.
     Include dependency audit step.
   - research.md - deep-read template: Files Involved, Request Flow,
     Boundaries Touched, Risks/Gotchas (min 3 with file:line evidence).
     Hard gate: no planning until human reviews output.
   - debug-investigate.md - diagnosis-first. "If you want to just try
     something before tracing the code path, STOP." Diagnosis output
     template with file:line evidence. No fixes until human reviews.
   - audit.md - 4-pass: Discovery -> Verification -> Prioritisation ->
     Self-Check ("did I fabricate this?"). MUST NOT propose fixes.
   - code-review.md - structured review with priority markers and
     autonomy tier awareness.

   Skip research.md and code-review.md for single-domain libraries.

5. Verification scripts (scripts/)
   - scripts/preflight-checks.sh - runs build, lint, test for the stack.
     Exit non-zero on failure.
   - scripts/context-validate.sh - checks AGENTS.md references exist,
     playbook files have required sections, and docs/footguns.md contains
     real evidence-backed entries or explicitly states "none confirmed yet".
   - scripts/deny-dangerous.sh - codifies the deny policy for
     human/agent review, preflight, and CI. It does NOT intercept
     commands automatically - Codex has no hook system. Reference
     this script from AGENTS.md rules and preflight checks.
     Document blocks for: rm -rf (unscoped), force push, .env edits,
     no-verify commits. Add project-specific blocks for files that
     must be modified through tooling.

6. Codex evals (codex-evals/)
   Create a README.md explaining what evals are and how to use them.

   Search git history for real incidents:
   git log --oneline --all | grep -iE 'fix|revert|bug|broke|regression'

   For each, create codex-evals/[incident-name].md with:
   - Origin: real-history | synthetic-seed
   - Bug description
   - Single replay prompt
   - Expected outcome
   - Failure mode tested

   If fewer than 5 real incidents, add from these common failure modes:
   - Question answered without code changes (CLASSIFY test)
   - Rename followed by grep for old pattern (VERIFY test)
   - Ask First boundary respected (autonomy test)
   - Debug diagnosis before fix attempt (ACT test)
   - Two failed approaches triggers stop (VERIFY test)

VERIFICATION:
- AGENTS.md exists and is concise
- All docs seed files exist (including tasks/todo.md and tasks/handoff.md)
- All playbook files exist with required sections
- Verification scripts are executable and run without errors
- Footguns are real (from codebase) with file:line evidence, or
  docs/footguns.md explicitly states "none confirmed yet"
- Evals reference real incidents where possible
- Router table in AGENTS.md points to all created files
- Report: AGENTS.md line count, number of playbooks, number of footguns,
  number of evals, guidelines file reduction (if applicable)
```

---

## After Codex Runs - Human Checklist

- [ ] AGENTS.md: does the execution loop read naturally, not like a copy of CLAUDE.md?
- [ ] Footguns: are they real? Check file:line references against actual code.
- [ ] Guidelines split: diff the before/after. Was anything useful dropped?
- [ ] Evals: do the replay prompts test what they claim to test?
- [ ] Verification scripts: run each one manually. Do they pass?
- [ ] Router table: click every reference. Do the files exist?
- [ ] Ask First boundaries: are they specific to THIS project, not generic?

---

## What This Intentionally Does Not Include

- **Hooks / automatic interception.** Codex has no hooks system. The
  deny-dangerous script codifies policy for review and CI - it does not
  block commands at runtime. AGENTS.md rules are behavioural guidance,
  not mechanical enforcement. This is the biggest capability gap vs
  Claude Code. Accept it and design around it: strong rules + preflight
  validation + CI checks.
- **Permission profiles.** Codex's sandbox model is different. Scoping is via
  AGENTS.md rules, not JSON profile files.
- **Local AGENTS.md files.** Directory-level auto-loading of instruction
  files has not been confirmed in Codex docs as of March 2026. Treat this
  as an implementation assumption. Put module warnings in docs/footguns.md
  and reference them from AGENTS.md's router table.
- **Slash commands.** Playbook files serve the same purpose - the agent reads
  them when the task matches. Reference them in AGENTS.md's router table.
- **Strict line count.** Codex's context model is per-task, not per-session.
  Keep AGENTS.md concise for clarity, not for a token budget ceiling.
