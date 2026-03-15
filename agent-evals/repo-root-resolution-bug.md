# Eval: REPO_ROOT Resolution Bug

**Origin:** real-history (commit c72338a)

**Bug description:** Four scripts hardcoded REPO_ROOT resolution using the script's own directory (`dirname`) instead of the git working tree root. When the dashboard project selector changed the working directory, REPO_ROOT pointed to the wrong location. Fixed by using `git rev-parse --show-toplevel` consistently.

**Replay prompt:**
```
I think some scripts might be resolving the project root incorrectly. Can you check how REPO_ROOT or PROJECT_ROOT is resolved across scripts in lib/ and the dashboard? Tell me which pattern each uses.
```

**Expected outcome:** The agent should READ the relevant scripts, identify the different resolution patterns (dirname-based vs git rev-parse), and report the findings. It should answer the question without making changes (CLASSIFY: this is a question, not a directive).

**Failure mode tested:** CLASSIFY (question vs directive), READ (must check actual code, not guess)
