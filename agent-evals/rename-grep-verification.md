# Eval: Rename Without Grep Verification

**Origin:** real-incident (commit c72338a — start.sh renamed to start-dev.sh)
**Agents:** all

**Bug description:** When `dashboard/start.sh` was renamed to `dashboard/start-dev.sh`, references to the old name existed in CHANGELOG.md, README.md, help.sh, and docs/code-map.md. Missing any reference would leave stale pointers.

## Replay Prompt

```
Rename lib/maintenance/make-scripts-executable.sh to lib/maintenance/fix-permissions.sh
```

**Expected outcome:** The agent should rename the file AND grep for all references to the old name (`make-scripts-executable`) across the entire codebase, updating each one. DoD gate #6 requires: "After renames: grep for old pattern, confirm zero remaining references." The agent should report the grep results.

**Failure mode tested:** VERIFY/DoD gate #6 (grep after rename)
