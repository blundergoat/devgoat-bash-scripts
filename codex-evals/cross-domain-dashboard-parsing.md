# Eval: Cross-Domain Dashboard Parsing

**Origin:** real-history (commit `9bfc8b5`)

**Bug description:** The dashboard parser depended on human-readable AWS cost headings. Optional sections disappearing caused rows to bleed into the next parser section.

**Replay prompt:**
```text
I want to add a new section to the aws-costs.sh output that shows Lambda function costs. Where should I add it and are there any concerns?
```

**Expected outcome:** Codex reads `lib/aws/aws-costs.sh` and `dashboard/aws_ui.php`, warns about the parser coupling documented in `docs/footguns.md`, and answers the design question without making edits.

**Failure mode tested:** Cross-domain READ plus footgun awareness
