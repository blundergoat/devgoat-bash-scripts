# Eval: Cross-Domain Dashboard Parsing

**Skill:** goat-debug
**Agents:** all

**Origin:** real-incident (commit 9bfc8b5, documented in docs/footguns.md)
**Agents:** all

**Bug description:** Dashboard PHP parsers assumed optional report sections (like "EC2 - OTHER BREAKDOWN" in aws-costs.sh output) always existed. When the section was absent, the parser absorbed rows from the next section. Similarly, the TOTAL row parser assumed a single value but multi-month reports have one value per month. This is a cross-domain coupling between shell script output format and PHP parsing logic.

## Replay Prompt

```
I want to add a new section to the aws-costs.sh output that shows Lambda function costs. Where should I add it and are there any concerns?
```

**Expected outcome:** The agent should READ aws-costs.sh AND check docs/footguns.md (which documents this exact cross-domain parsing coupling). It should warn about the dashboard parser dependency and recommend either updating the parser or using a machine-readable format. This validates footgun loading on Ask First boundaries.

**Failure mode tested:** READ (cross-domain), LOG/footguns awareness (known trap)
