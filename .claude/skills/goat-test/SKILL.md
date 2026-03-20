# /goat-test — Testing Instructions Generator

Generate testing instructions after a milestone or coding session. Based on the doer-verifier principle: the coding agent MUST NOT verify its own work.

## When to Use

After completing implementation work, before declaring a milestone done. The agent that wrote the code generates the test plan but does NOT execute Track 2.

## Track 1: Automated Tests (agent runs these)

Produce the exact commands to run:

```
bash -n <changed files>
shellcheck <changed files>
bats tests/ --recursive
./preflight-checks.sh
```

Include any additional test commands specific to the change (e.g., `curl` smoke tests, script dry-runs with `--help`).

## Track 2: AI Verification (separate fresh agent)

Generate pre-filled prompts for a SEPARATE agent session. The verifier agent should:
- Review the diff without knowledge of the implementation intent
- Check for regressions, missed edge cases, and convention violations
- Verify the change against `docs/footguns.md` entries

Recommend cross-model verification when possible (e.g., if Claude wrote the code, use Codex or Gemini to verify). Same-model verification is acceptable when cross-model is not available.

### Prompt Template

```
Read these files: [list changed files]
Read docs/footguns.md.

Review the recent changes for:
1. Regressions against existing behaviour
2. Convention violations (shebang, strict mode, logging paradigm)
3. Cross-domain impacts documented in footguns.md
4. Edge cases: empty input, missing files, permission errors

Report findings with file:line evidence. Do not fix anything.
```

## Track 3: Human Testing (developer runs these)

Numbered manual checklist. Each item must be:
- Concrete and actionable (not "verify it works")
- Testable in under 2 minutes
- Focused on behaviour the automated tests cannot catch (visual output, interactive prompts, platform-specific behaviour)

### Example Format

```
1. Run `./lib/aws/aws-costs.sh --help` and verify help text displays
2. Run with no AWS credentials and verify the error message is clear
3. On WSL: verify the script does not resolve /mnt/* binaries
```

## Output Format

```md
## Track 1: Automated Tests
[exact commands]

## Track 2: AI Verification
[pre-filled prompt for separate agent]

## Track 3: Human Testing
[numbered checklist]
```
