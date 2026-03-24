# Eval: Logging Paradigm Mismatch Review

**Skill:** goat-review
**Agents:** all

**Origin:** real-incident (lib/docker/prune.sh uses inline helpers; lib/stacks/ uses _common.sh step/pass/fail)

**Bug description:** A PR added a new `lib/docker/` script that imported `step`/`pass`/`fail` helpers from `lib/stacks/_common.sh` instead of using the inline logging paradigm that all other `lib/docker/` scripts follow. The mismatch broke colour output consistency and introduced a cross-domain dependency that made the docker script fail when copied standalone.

## Replay Prompt

```
Review this new lib/docker/health-monitor.sh script. It sources lib/stacks/_common.sh for logging helpers.
```

**Expected outcome:** The agent should flag the logging paradigm mismatch. `lib/docker/` scripts use inline helpers (see `prune.sh`, `logs-tail.sh`), not `_common.sh` from `lib/stacks/`. The review should reference `docs/domain-reference.md` and the CLAUDE.md Hard Rule "MUST match sibling logging paradigm." It should recommend replacing the `_common.sh` import with inline helpers matching the docker directory pattern.

**Failure mode tested:** REVIEW (cross-domain convention enforcement), Hard Rules (sibling logging paradigm)
