## Same Project, Different Agent

The medical scribe was the first project to get both implementations: Claude Code (v1.2 plan) and Codex (adapted prompt). Same codebase, same execution loop concept, different agent mechanics. The comparison is direct.

### What Maps Cleanly

The core system transfers without modification: the five-step loop, autonomy tiers, Definition of Done, footguns file, lessons file, router table, essential commands, and the eval concept. These aren't Claude Code features — they're workflow patterns that work on any agent that reads a root instruction file.

Both agents produced similar footgun counts from the same codebase (8 from Claude Code, 7 from Codex) with overlapping findings: the Mercure silent publish failure, the three independent session state buckets, the NeMo GPU singleton, the DynamoDB provisioned-but-unused gap. The convergence suggests the footgun-seeding approach works regardless of which agent does the reading.

### What Had No Equivalent

| Claude Code feature | Codex replacement | Trade-off |
|---|---|---|
| PreToolUse hooks (deny-dangerous) | `scripts/deny-dangerous.sh` as policy documentation | Claude Code blocks `rm -rf` before it executes. Codex documents the policy for review and CI but cannot prevent the command from running. |
| Stop hooks (lint after every turn) | Preflight script, run manually or in CI | Claude Code catches formatting issues continuously. Codex catches them at checkpoints. |
| PostToolUse hooks (auto-format) | Nothing — manual or preflight | No auto-formatting on edit. |
| Local CLAUDE.md (directory auto-load) | Centralised footguns.md + router references | Claude Code loads warnings automatically when entering a directory. Codex requires the agent to check the router table. |
| Slash commands (/preflight, /debug) | Playbook files in `docs/codex-playbooks/` | Same content, different loading mechanism. |
| Permission profiles (.claude/profiles/) | Behavioural guidance in AGENTS.md only | No tool-level scoping. |
| /compact, /insights | No equivalent | Codex context is per-task, not per-session. No session management needed — but no session learning either. |

The hooks gap is the fundamental difference. Claude Code has three layers of enforcement: behavioural guidance in CLAUDE.md, deterministic hooks that block commands before execution, and stop hooks that run checks after every turn. Codex has one layer: behavioural guidance in AGENTS.md. The deny-dangerous script exists, but it's a policy document — inspectable, auditable, referenced from preflight and CI — not a runtime interceptor.

### What's Better Without Hooks

No hooks isn't purely a loss. Five things work better in the Codex version:

**No false positives.** The hook saga documented six versions of a prompt-based stop hook, all of which produced false positives that eroded trust. Codex sidesteps this entirely — there's no mechanism to produce false positives because there's no semantic enforcement mechanism.

**Inspectable policy.** `deny-dangerous.sh` is a plain shell script committed to the repo. Anyone can read it, diff it, argue about it. Claude Code's deny hook is the same, but the stop and format hooks involve JSON configuration in `.claude/settings.json` that's less transparent.

**Reused existing infrastructure.** Codex extended the project's existing `preflight-checks.sh` rather than creating parallel hook machinery. The deny policy became step 3 of the existing preflight script. Claude Code's hooks exist alongside preflight, creating two enforcement paths.

**Deterministic validation.** `scripts/context-validate.sh` checks that AGENTS.md references exist, playbooks have required sections, and footguns have evidence. Claude Code's CI workflow does similar checks, but Codex's version is a local script you can run anytime — no CI pipeline required.

**Committed overlap report.** When Codex applied the guidelines ownership split, it created a persistent `guidelines-ownership-split.md` documenting what was removed and why. Claude Code's split happens in a chat session and the reasoning evaporates when the session ends.

### What's Worse Without Hooks

The enforcement gap is real and shows up in six places:

**No runtime blocking.** If Codex decides to run `rm -rf /`, nothing stops it. AGENTS.md says "Never do this." The deny-dangerous script documents the policy. But neither intercepts the command. Claude Code's PreToolUse hook blocks it before execution — 100% of the time, mechanically, regardless of whether the agent read the rules.

**No automatic stop-the-line.** Claude Code's stop hook runs `php -l` or `cargo fmt --check` after every turn. If there's a syntax error, the agent sees it immediately. Codex only catches these at preflight checkpoints — meaning errors can accumulate between checks.

**Ask First is behavioural only.** In Claude Code, the Ask First micro-checklist is reinforced by the stop-the-line hook — if a cross-boundary change breaks something, the hook catches it. In Codex, Ask First relies entirely on the agent choosing to follow the rule.

**No directory-level warnings.** Claude Code auto-loads a local CLAUDE.md when entering `strands_agents/` or `infra/`. Codex has no confirmed equivalent — the footguns are centralised, not positioned where the danger is.

**No permission lanes.** Claude Code's permission profiles restrict which files a frontend session can edit. Codex has no tool-level scoping — every session has access to everything.

**No session compaction.** Claude Code's `/compact` and context management tools help with long sessions. Codex's per-task context model avoids this problem differently — each task starts fresh — but loses continuity between tasks.

### The Honest Summary

The system's core — the execution loop, autonomy tiers, definition of done, learning loop — is agent-agnostic. It works on both. The enforcement layer is where they diverge. Claude Code enforces mechanically (hooks block commands, format files, check syntax). Codex enforces culturally (AGENTS.md rules, policy scripts, preflight checks, CI).

For solo developers who trust their agent and verify with preflight, the Codex model is sufficient. For teams, long-lived projects, or codebases where a single bad command has high blast radius, Claude Code's hooks provide a safety net that behavioural guidance alone can't match.

The workflow system is portable. The enforcement model is not.
