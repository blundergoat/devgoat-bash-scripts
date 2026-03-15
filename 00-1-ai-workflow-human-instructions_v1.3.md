# AI Workflow Improvement — Human Instructions

**Version:** 1.1 | 2026-03-14
**Companion to:** `ai-workflow-improvement-plan-prime.md` (plan) and `ai-workflow-implement-prompts-prime.md` (prompts)

---

## Reading Order

1. **This file** — how to start
2. **The article** (`ai-workflow-ARTICLE-prime.md`) — why this exists, real implementation data
3. **The prompts** (`ai-workflow-implement-prompts-prime.md`) — what you run
4. **The plan** (`ai-workflow-improvement-plan-prime.md`) — full reference for every design decision
5. **The rationale** (`ai-workflow-design-rationale-prime.md`) — deep dives on why each section exists

## What This Is

A system that gives Claude Code a 5-step execution loop (READ → CLASSIFY → ACT → VERIFY → LOG) instead of a wall of rules. Two files do the work — a design doc (the plan) and a set of prompts you feed to Claude Code. You run the prompts; Claude Code builds the system for your project.

## Before You Start

1. **Copy both files into your project root:**
   - `ai-workflow-improvement-plan-prime.md`
   - `ai-workflow-implement-prompts-prime.md`

2. **Rename if needed.** The prompts reference `ai-workflow-improvement-plan-prime.md` by exact filename. If your copies have prefixes or version suffixes, rename them to match.

3. **Audit your existing guidelines file.** If you have an `ai-agent-guidelines.instructions.md` (or similar), open the prompts file and read the "Before You Start: Guidelines Ownership Audit" section. Remove overlapping content from guidelines *manually* before running any prompts. This is the one step you do by hand.

4. **Know your project shape.** You'll need to fill in blanks in the prompts:
   - Is this an **APP** or a **LIBRARY**?
   - Languages, build command, test command, lint command, format command

## Implementation Order

Run these in Claude Code. Copy each prompt from the prompts file, fill in the bracketed placeholders, paste into Claude Code.

| Step | Prompt | What It Creates | Time |
|------|--------|-----------------|------|
| **Phase 0** | Phase 0 bootstrap | CLAUDE.md + deny-dangerous hook + settings.json | ~5 min |
| **Phase 1a** | Prompt A (new) or Prompt B (existing CLAUDE.md) | CLAUDE.md, docs seed files, architecture.md, local CLAUDE.md files | ~15 min |
| **Phase 1b** | Phase 1b — Skills | 3-5 skill files under `.claude/skills/` | ~10 min |
| **Phase 1c** | Phase 1c — Enforcement | Hooks, CI workflow, gitignore additions | ~10 min |
| **Phase 2** | Phase 2 | Agent evals, RFC 2119 pass, permission profiles | ~15 min |

**Skip Phase 0** if you're running Phase 1 (Phase 0 is a minimal bootstrap for when you want just the basics).

**Phase 2 can run immediately after Phase 1** — the medical scribe ran all phases in one session. Waiting gives you more real incidents for evals, but even early-stage projects with a short git history can seed useful evals.

## Choosing Your Path

```
New project, no CLAUDE.md exists?
  → Phase 0 (minimal) OR Phase 1a Prompt A (full)

Existing project with a CLAUDE.md full of domain content?
  → Phase 1a Prompt B (migrates domain content to docs/domain-reference.md)

Just want the bare minimum to try it?
  → Phase 0 only. Add skills and hooks later.
```

## What to Check After Each Phase

**After Phase 1a:**
- [ ] CLAUDE.md line count reported — under 120 (apps) or 100 (libraries)?
- [ ] If Prompt B: open `docs/domain-reference.md` and verify nothing was silently dropped. Compare against the original CLAUDE.md
- [ ] `docs/footguns.md` contains real footguns with file:line evidence, not hypothetical ones
- [ ] Budget a second pass — agents aggressively cut content during compression. The anti-BDUF guard is commonly dropped then needed back

**After Phase 1b:**
- [ ] Router table in CLAUDE.md references all skill directories
- [ ] Preflight checks pass

**After Phase 1c:**
- [ ] `.claude/settings.json` is valid JSON
- [ ] Test the deny-dangerous hook: ask Claude Code to run `rm -rf /` — it should be blocked
- [ ] Stop hook exits 0 even when it finds issues (non-zero = infinite loops)

**After Phase 2:**
- [ ] CLAUDE.md still under line target after RFC 2119 pass
- [ ] Agent evals are from real incidents, not invented scenarios

## The Adoption Tiers

You don't have to do everything. Pick your tier:

| Tier | What You Run | Good For |
|------|-------------|----------|
| **Minimal** | Phase 0 only | Trying it out, solo project |
| **Standard** | Phase 1a + 1b + 1c | Active development |
| **Full** | Phase 1 + Phase 2 | Long-lived project with incident history |

## Ongoing Maintenance

**Weekly:** Run `/insights` in Claude Code (analyses your recent session history for recurring patterns). Look for friction that could become a new rule or footgun.

**When something breaks:** After Claude causes a bug, add it to `docs/lessons.md` (behavioural) or `docs/footguns.md` (architectural). If it's worth regression-testing, create an agent eval in `agent-evals/`.

**Quarterly:** Re-count CLAUDE.md lines. Check for stale rules. Ask: "if I removed this, would the model still do the right thing?" Archive lessons not triggered in 30+ days.

**When models improve:** The system is designed to shrink. Rules that compensated for model weaknesses become unnecessary. Delete them.

## Common Gotchas

- **Consider separate sessions per phase.** The prompts were split to stay within instruction budget. One session per phase is safest. If context budget allows (smaller codebases), running all phases sequentially in one session can work — the medical scribe did this successfully.
- **The migration (Prompt B) drops content silently.** Sections that partially overlap with your guidelines file get cut without warning. Always diff.
- **First-pass CLAUDE.md is usually over target.** Budget a compression pass. The plan has a cut priority list — essential commands go first, execution loop never gets cut.
- **Hooks must use absolute paths.** All hook commands use `git rev-parse --show-toplevel`. Relative paths break when the working directory changes.
- **Stop hooks must exit 0.** Even when they find errors. Non-zero exit codes trap Claude in infinite fix loops.
- **Secret scanning is manual.** The `gitleaks` setup requires `git config --global` which affects all repos. Do it yourself, don't let Claude Code do it.

## File Reference

After full implementation, your project will have:

```
CLAUDE.md                              ← Layer 1: the loop (~100-120 lines)
src/auth/CLAUDE.md (etc.)              ← Layer 2: local context (if qualifying dirs exist)
.claude/skills/preflight/SKILL.md      ← Layer 3: skills
.claude/skills/debug-investigate/SKILL.md
.claude/skills/audit/SKILL.md
.claude/skills/research/SKILL.md       ← apps only
.claude/skills/code-review/SKILL.md    ← apps only
.claude/hooks/deny-dangerous.sh        ← enforcement
.claude/hooks/stop-lint.sh
.claude/hooks/format-file.sh
.claude/settings.json
docs/lessons.md                        ← learning loop
docs/footguns.md
docs/confusion-log.md                  ← apps only
docs/architecture.md
docs/domain-reference.md               ← Prompt B path only
docs/decisions/                        ← apps only
tasks/handoff-template.md
agent-evals/                           ← Phase 2
.github/workflows/context-validation.yml  ← Phase 2
```

## Further Reading

- **The plan** (`ai-workflow-improvement-plan-prime.md`) — full system design, rationale for every section, hook design patterns, security hardening details
- **The article** (`ai-workflow-ARTICLE-prime.md`) — narrative version with real implementation data from two projects
- **The playbook repo** ([ai-planning-playbook](https://github.com/blundergoat/ai-planning-playbook)) — planning prompts (mob elaboration, SBAO ranking, milestone planning) that feed into Phase 2 playbook updates
- **Codex adaptation** (`codex-workflow-implement-prompt.md`) — implementation prompt for adapting the workflow system to OpenAI Codex
