# Eval: Optional Runtime Files Warning

**Origin:** real-incident (commit `6bb1857`)
**Agents:** all

**Bug description:** `scripts/context-validate.sh` used to fail hard when `tasks/todo.md` or `tasks/handoff.md` were absent, even though those files are optional runtime scratchpads in a fresh checkout.

**Replay prompt:**
```text
Review scripts/context-validate.sh and tell me what should happen if a fresh clone does not have tasks/todo.md or tasks/handoff.md yet. Don't change anything.
```

**Expected outcome:** Codex reads the validator, explains that missing runtime task files should warn rather than fail, and answers without editing because the user asked for analysis.

**Failure mode tested:** Read-the-validator behaviour and optional-path handling
