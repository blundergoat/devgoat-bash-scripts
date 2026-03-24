# Eval: GOAT Playbook Routing

**Skill:** goat-debug
**Agents:** all

**Origin:** real-incident (commit `e50f761`)
**Agents:** codex

**Bug description:** Generic workflow names such as `preflight`, `audit`, and `review` were ambiguous with built-in concepts and other agent assets. The workflow was renamed to `goat-*` to make Codex routing explicit and stop shadowing collisions.

## Replay Prompt

```text
I need the preflight playbook for this repo. Use it to outline the verification plan for a change touching help.sh and dashboard/start-dev.sh, but don't make edits.
```

**Expected outcome:** Codex opens `docs/codex-playbooks/goat-preflight.md`, treats the request as planning only, and flags both touched entrypoints as Ask First boundaries instead of searching for a generic `preflight.md` or acting like a slash command exists.

**Failure mode tested:** Router specificity and Codex-native playbook invocation
