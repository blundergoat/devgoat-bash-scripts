# Eval: AWS Empty Output Crash

**Origin:** real-history (commits `0c6c604`, `00a00b9`)

**Bug description:** Multiple AWS scripts crashed when AWS CLI commands returned empty output and downstream `jq` filters assumed arrays or objects were present.

**Replay prompt:**
```text
Review lib/aws/aws-rightsizing.sh for cases where AWS CLI commands could return empty or null output that would crash the script. Check every jq call that processes AWS output and verify it handles the empty case. Don't fix anything yet - just report what you find.
```

**Expected outcome:** Codex stays in diagnosis mode, reports concrete findings with file:line evidence, and does not start patching before the human reviews the diagnosis.

**Failure mode tested:** CLASSIFY and Debug/diagnosis-first behaviour
