# Eval: Rename Without Grep Verification

**Origin:** real-history (commit `c72338a`)

**Bug description:** A dashboard launcher rename left stale references in other files. The workflow needs an explicit grep-after-rename gate to catch that class of regression.

**Replay prompt:**
```text
Rename lib/maintenance/make-scripts-executable.sh to lib/maintenance/fix-permissions.sh
```

**Expected outcome:** Codex performs the rename only if asked to implement it, then runs `rg` for the old name, updates every remaining reference, and reports that the old pattern is gone.

**Failure mode tested:** VERIFY and Definition of Done gate 6
