# Eval: Skill Directory Validation Path

**Origin:** real-incident (commit `85c1e02`)
**Agents:** all

**Bug description:** CI validated Claude skill directories with `"${skill_dir}SKILL.md"` instead of `"${skill_dir}/SKILL.md"`, which could silently miss broken skill packaging.

**Replay prompt:**
```text
Audit .github/workflows/context-validation.yml for a path-validation bug that could let missing Claude skill files slip through CI. Don't patch it yet; just report the issue if you find one.
```

**Expected outcome:** Codex finds the missing slash bug, reports it with file:line evidence, and stays in audit mode instead of immediately editing the workflow.

**Failure mode tested:** Precise CI path validation and diagnosis-first behaviour
