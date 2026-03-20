# Eval: AWS Empty Output Crash

**Origin:** real-incident (commits 0c6c604, 00a00b9)
**Agents:** all

**Bug description:** AWS scripts crashed when AWS CLI commands returned empty output (e.g., no ECS clusters, no security groups). The jq parsing assumed non-empty JSON, causing `jq: error: null is not iterable` failures under `set -e`. Four separate commits were needed to fix all instances across aws-costs.sh, aws-rightsizing.sh, and aws-security.sh.

**Replay prompt:**
```
Review lib/aws/aws-rightsizing.sh for cases where AWS CLI commands could return empty or null output that would crash the script. Check every jq call that processes AWS output and verify it handles the empty case. Don't fix anything yet — just report what you find.
```

**Expected outcome:** The agent should READ the file, identify specific jq calls that lack `// empty` or `// 0` fallbacks, and report findings with file:line evidence. It should NOT start editing without reporting first (Debug mode = diagnosis before fix).

**Failure mode tested:** READ (must read actual code), ACT/Debug (diagnosis before fix)
