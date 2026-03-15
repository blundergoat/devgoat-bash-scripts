# Footguns

Cross-domain gotchas confirmed in this codebase. Add entries only when the repo itself demonstrates the behaviour.

## Footgun: Helper sourcing is directory-specific

**Symptoms:** A copied script cannot find its helper library, or it sources the wrong shared file after being moved.

**Why it happens:** `ai-cli`, `stacks`, and `aws` each resolve shared helpers differently, and the patterns are tied to the directory layout.

**Evidence:**
- `lib/ai-cli/install-claude.sh:11`
- `lib/stacks/node/setup.sh:17`
- `lib/aws/aws-cli.sh:13`

**Prevention:** Match the helper source pattern used by sibling files in the same domain. Do not swap `SCRIPT_DIR/_common.sh` and `../_common.sh`.

## Footgun: Only ai-cli sanitises WSL PATH

**Symptoms:** A script resolves Windows binaries from `/mnt/*` inside WSL and then fails in confusing ways.

**Why it happens:** `ai-cli/_common.sh` rejects `/mnt/*` binaries and strips those PATH entries before Node/npm checks. Other domains rely on plain `command -v`.

**Evidence:**
- `lib/ai-cli/_common.sh:54`
- `lib/ai-cli/_common.sh:65`
- `lib/aws/_aws-common.sh:101`
- `lib/workflow/git-status.sh:44`

**Prevention:** If a non-ai-cli script must be WSL-safe, add an explicit native-binary check or document the assumption instead of assuming shared sanitisation exists.

## Footgun: Strict-mode exceptions are intentional

**Symptoms:** Adding `set -e` to a verify or preflight script causes it to abort before reporting the full failure summary.

**Why it happens:** Some scripts intentionally use `set -uo pipefail` so they can accumulate failures. The root preflight script hard-codes these exceptions.

**Evidence:**
- `lib/stacks/php/verify.sh:12`
- `lib/stacks/node/preflight-checks.sh:8`
- `lib/health/check-gpu.sh:21`
- `preflight-checks.sh:251`

**Prevention:** Before changing strict mode, check whether the script is expected to keep running after a failed check and whether `preflight-checks.sh` already treats it as an exception.

## Footgun: Logging style is domain-scoped

**Symptoms:** A new script looks out of place because the log format, colours, or helper names do not match its neighbours.

**Why it happens:** The repo uses at least three logging styles: ai-cli colour output, stacks `step`/`pass` helpers, and standalone inline log functions.

**Evidence:**
- `lib/ai-cli/install-claude.sh:16`
- `lib/stacks/node/setup.sh:45`
- `lib/aws/cloudfront-invalidate.sh:56`
- `lib/maintenance/git-cleanup.sh:8`

**Prevention:** Read one sibling script in the touched directory before introducing a new logging helper or output style.

## Footgun: Root preflight only scans lib scripts

**Symptoms:** A root shell entrypoint, dashboard launcher, or workflow helper passes unnoticed even though it has syntax or lint issues.

**Why it happens:** `preflight-checks.sh` discovers scripts only under `lib/`, while valid shell entrypoints also exist at the repo root and under `dashboard/`.

**Evidence:**
- `preflight-checks.sh:242`
- `help.sh:1`
- `dashboard/start-dev.sh:1`

**Prevention:** When changing shell files outside `lib/`, run explicit `bash -n` and `shellcheck` on them or use `scripts/preflight-checks.sh`.

## Footgun: Dashboard AWS parsing depends on exact report headings

**Symptoms:** A dashboard section absorbs rows from the next section, or totals drift after a shell report heading changes.

**Why it happens:** `dashboard/aws_ui.php` slices human-readable AWS cost output by heading names such as `EC2 - OTHER BREAKDOWN`. The shell producer emits those headings directly.

**Evidence:**
- `lib/aws/aws-costs.sh:323`
- `lib/aws/aws-costs.sh:335`
- `dashboard/aws_ui.php:1071`
- `dashboard/aws_ui.php:1078`

**Prevention:** Read the shell report and the PHP parser together before changing section names or row shapes. If the coupling grows, add a machine-readable output mode instead of scraping terminal text.
