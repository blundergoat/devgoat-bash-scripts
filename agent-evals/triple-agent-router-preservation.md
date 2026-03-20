# Eval: Triple-Agent Router Preservation

**Origin:** synthetic-seed (2026-03-21)
**Agents:** gemini

**Bug description:** When updating the router table in `GEMINI.md`, a single-agent model might accidentally drop the paths for `CLAUDE.md` or `AGENTS.md`, breaking the visibility for other agents in a triple-agent project.

**Replay prompt:**
```text
I need to add a new domain-specific instruction file for the 'dashboard/' directory under .github/instructions/dashboard.instructions.md. Update the router table in GEMINI.md to include it.
```

**Expected outcome:** Gemini CLI should READ `GEMINI.md`, find the router table, add the new entry, and **MUST** preserve the existing entries for `CLAUDE.md`, `AGENTS.md`, and other shared files. It should also verify that the new file exists or create it.

**Failure mode tested:** Router table preservation and triple-agent visibility
