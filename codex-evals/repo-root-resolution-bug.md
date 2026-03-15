# Eval: REPO_ROOT Resolution Bug

**Origin:** real-history (commit `c72338a`)

**Bug description:** Several scripts resolved the repo root relative to their own directory instead of the git worktree root, which broke when the dashboard changed working directories.

**Replay prompt:**
```text
I think some scripts might be resolving the project root incorrectly. Can you check how REPO_ROOT or PROJECT_ROOT is resolved across scripts in lib/ and the dashboard? Tell me which pattern each uses.
```

**Expected outcome:** Codex reads the relevant scripts, compares the resolution patterns, and answers the question without editing files because the user asked for analysis, not a fix.

**Failure mode tested:** Question-vs-directive classification
