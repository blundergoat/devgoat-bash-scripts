# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).

---

## [v1.5.0] - 2026-03-21

### Added

- **GOAT Flow** — adopted GOAT Flow system spec across CLAUDE.md and AGENTS.md.
  - SCOPE step added to execution loop (READ → CLASSIFY → SCOPE → ACT → VERIFY → LOG).
  - CLASSIFY now includes complexity budgets: Hotfix (2/3), Standard (4/10), System (6/20), Infra (8/25).
  - ACT requires explicit mode-transition declarations.
  - LOG upgraded from SHOULD to MUST with mechanical trigger and human-correction rule.
  - Ask First expanded to explicit 5-item micro-checklist in both files.
  - Debug mode: "No fixes until human reviews diagnosis."
- **Consolidated agent-evals/** — merged `codex-evals/` into `agent-evals/` with `Agents:` label (all/codex) on every eval. 3 Codex-specific evals added, 0 duplicates.
- **Write/Edit enforcement** — `deny-dangerous.sh` now inspects Write/Edit tool calls for .env, lockfile, and generated code modifications (previously Bash only).
- **Read deny patterns** — `settings.json` blocks `Read(.env*)`, `Read(**/secrets/**)`, `Read(**/*.pem)`, `Read(**/*.key)`.
- **Agent ignore files** — `.copilotignore` and `.cursorignore` with secret patterns.
- **docs/lessons.md seeded** — first entry from rename-grep-verification incident (commit c72338a).

### Changed

- **AGENTS.md** — RECORD renamed to LOG, Sub-Agent Objectives and Communication When Blocked sections added.
- **Skills renamed** — `preflight/` → `goat-preflight/`, `code-review/` → `goat-review/`, `debug-investigate/` → `goat-debug/`, `audit/` → `goat-audit/`, `research/` → `goat-research/`.
- **Codex playbooks renamed** — `preflight.md` → `goat-preflight.md`, etc.
- **CI workflow** — added AGENTS.md line count validation, router table reference checks, removed `codex-evals/` trigger.
- **scripts/context-validate.sh** — updated to validate consolidated `agent-evals/` with `Agents:` heading check.
- **scripts/deny-dangerous.sh** — Codex deny policy updated for Write/Edit tool awareness.
- **.gitignore** — organised into logical sections; added `.claude/projects/`, `.claude/worktrees/`.

### Removed

- **codex-evals/** — consolidated into `agent-evals/`.
- **Old skill directories** — replaced by `goat-*` prefix names.
- **Old Codex playbook names** — replaced by `goat-*` prefix names.

---

## [v1.4.0] - 2026-03-15

### Added

- **Tunnel system** — provider-agnostic tunnel management built into the dashboard.
  - One-click Cloudflare quick tunnel with cloudflared process lifecycle management.
  - Manual URL support for ngrok, localhost.run, Tailscale Funnel, or any provider.
  - Recent URLs saved in localStorage (last 5, click to re-use).
  - Live uptime timer, auto-refresh polling (20s), and cloudflared log viewer.
  - Inline connectivity tester (GET/HEAD) with result alerts and curl preview.
  - Browser notification when tunnel is ready.
  - `dashboard/tunnel.php` — UI fragments (CSS, HTML, JS).
  - `dashboard/index.php` — tunnel API endpoints: start, stop, configure, test, status, logs.
  - `dashboard/start-dev.sh` — cleanup trap kills orphaned cloudflared on Ctrl+C.

- **AWS reports backend and UI** — full AWS operations console accessible from the dashboard.
  - `dashboard/aws.php` — report execution backend and API handlers.
  - `dashboard/aws_ui.php` — tabbed UI with overview cards, cost analysis, rightsizing, security scanning, and CLI runner. Each tab retains its last result.
  - `lib/aws/_aws-common.sh` — shared AWS auth and .env loader.
  - `lib/aws/aws-costs.sh` — Cost Explorer analysis with service breakdown table.
  - `lib/aws/aws-rightsizing.sh` — CloudWatch metrics and utilisation analysis for RDS, ECS, ALB, NAT, EC2.
  - `lib/aws/aws-security.sh` — read-only scan of WAF rules, IAM users, security groups, S3 access blocks, and secrets rotation.
  - `.env.example` — AWS credential template.

- **Shared UI patterns** — reusable CSS classes added to both dashboard and AWS pages.
  - `.status-badge` — inline dot + label indicator (success, error, warning, running, idle) with optional pulse animation.
  - `.result-alert` — dismissible feedback banner with colored left border and slide-in animation.
  - `.collapsible-header` / `.collapsible-body` — animated expand/collapse sections with rotating chevron.
  - `focus-visible` outlines on all interactive elements for keyboard navigation.

### Changed

- **Dashboard terminal** — completion and stop results now show a fixed result-alert banner above the scrollable output (always visible, dismissible).
- **Dashboard sidebar** — running script indicator uses left accent border. Category chevrons changed from `▾` to `▸` with consistent rotation direction.
- **Dashboard welcome state** — centered flex layout instead of left-aligned italic text.
- **Dashboard footer** — smaller, subtler attribution text with hover opacity.
- **Dashboard Stop button** — disabled state no longer shows pink/red tint; neutralized to standard greyed-out appearance.
- **Tunnel page layout** — status card is full-width hero; tunnel URL displayed at 14px bold mono with click-to-copy. Notes section collapsed into "Paste Tunnel URL" card as expandable "Usage Notes". Quick Start card visually differentiated with accent border.
- **Tunnel globe button** — now shows "Tunnel" text label alongside icon for discoverability. Added `aria-label`.
- **Tunnel test buttons** — "Open URL" and "Copy curl" de-emphasized; all test controls disabled when no tunnel URL is configured.
- **Tunnel test results** — use `.result-alert` pattern instead of loose colored text.
- **AWS reports Total Cost** — hero card treatment with 24px bold mono number and accent left border.
- **AWS reports cost table** — inline proportional bar visualization behind each numeric cell. Added `tabular-nums` for vertical digit alignment.
- **AWS reports overview cards** — hover elevation effect. Active tab highlights its matching overview card with accent border.
- **AWS reports completion** — last-run status line shows badge, command, duration, and timestamp after report finishes.
- **AWS reports theme toggle** — changed from "Toggle Theme" text button to icon-only moon SVG matching main dashboard.
- **AWS reports back link** — text changed from "← Main Dashboard" to "← Back to Dashboard" for consistency with tunnel page.
- **`lib/aws/aws-cli.sh`** — updated wrapper with shared auth loader integration.

---

## [v1.3.0] - 2026-03-01

### Added

- **Rust stack scripts** - added `lib/stacks/rust/` with setup, verify, preflight, dependency install/update scripts.
- **`lib/docker/`** - docker compose wrappers: up, down, restart, prune, logs-tail, network-heal, mount-doctor.
- **`lib/workflow/`** - help-index, git-change-branch, git-status, sync-env.
- **`lib/health/`** - check-api-auth, check-gpu, load-test, port-check.
- **`lib/aws/health-check.sh`** - comprehensive AWS infrastructure health check (credentials, Secrets Manager, ECS, API, DynamoDB, CloudWatch). Moved from `lib/health/check-remote.sh`.

### Changed

- **`help.sh` now delegates** to `lib/workflow/help-index.sh` for categorized script listing with keyword search.
- **`preflight-checks.sh` restored to standalone** - self-contained 7-check quality gate (shebang, strict mode, executable bit, bash -n, shellcheck, no secrets staged, bats tests). No longer delegates.
- **`git-change-branch.sh` safe branch switching** - now stashes uncommitted changes and fetches before checkout. Accidental switches are reversible with `git stash pop`.
- **Dashboard process management** - `dashboard/index.php` no longer requires ext-posix; process checks/signals now use shell-based helpers.
- **Stack DB rebuilds** - stack-specific `lib/stacks/*/rebuild-database.sh` scripts handle DB rebuilds directly.

### Removed

- **`lib/dev/`** - all legacy compatibility wrappers removed (no deprecation period).
- **`lib/deps/`** - stacks handle dependencies directly via `lib/stacks/*/dependencies-*.sh`.
- **`lib/quality/`** - preflight-checks.sh is now standalone; lint scripts removed.
- **`lib/db/`** - replaced by `lib/stacks/*/rebuild-database.sh`.
- **`lib/workflow/`** project-specific scripts - rebuild-full.sh, rebuild-smart.sh, setup-initial.sh, setup-verify.sh, stop-dev.sh, switch-mode.sh.
- **`lib/health/`** project-specific scripts - report.sh, check-local.sh, check-remote.sh, check-aws.sh.
- **`lib/aws/`** project-specific scripts - deploy.sh, deploy-ecr-ecs.sh, amplify-health-check.sh, amplify-variables-get.sh, amplify-variables-set.sh.
- **`lib/maintenance/lint-all.sh`**

### Documentation

- Updated `README.md`, `docs/code-map.md`, `CLAUDE.md`, `AGENTS.md`, and `GEMINI.md` for the simplified structure.
- Removed stale bats test referencing deleted `lib/quality/` scripts.

## [v1.2.0] - 2026-03-01

### Added

- **`lib/dev/git-status.sh`** - drop-in script showing branch, recent commits, and working tree status.
- **`lib/dev/git-checkout.sh`** - drop-in script to switch branches with remote tracking support.
- **Dashboard: Copy button** - copy terminal output to clipboard from the toolbar.
- **Dashboard: Config banner** - shows a warning when using the unedited example config, with dismiss button.
- **Dashboard: BlunderGOAT branding** - logo in header, "created by BlunderGOAT" footer link.
- **Dashboard: Request logging** - `[dashboard] RUN/DONE/STOP` events in terminal output, TCP noise filtered.
- **Dashboard: Dynamic target badge** - env-badge updates to show the current target project folder name.
- **Dashboard: Prompt optional flag** - prompts can set `'optional' => true` to allow empty input (e.g. port-check).
- **Dashboard: Image serving** - route for `/blundergoat-avatar.jpg`.
- **`dashboard/config.php`** added to `.gitignore` - personal configs stay local.

### Changed

- **`port-check.sh` default ports** - expanded from 5 to 10 common dev ports: 3000, 3306, 5432, 6379, 8000, 8080, 8081, 8082, 8899, 11434 (covers MySQL, Postgres, Redis, PHP/Python dev servers, Go APIs, Ollama).
- **`port-check.sh` comma-separated input** - accepts `port-check.sh 3306,6379,8080` in addition to space-separated.
- **`dashboard/start-dev.sh` project name** - default changed from `my-project` to `DevGoat DevEx Dashboard`.
- **`dashboard/start-dev.sh` SCRIPTS_DIR** - default changed from `scripts` to `.` (project root).
- **`dashboard/start-dev.sh` logging** - filters PHP built-in server TCP noise, only shows `[dashboard]` tagged events.
- **`dashboard/config.example.php`** - reorganized into `devgoat-bash-scripts`, `Quick Info`, and `Maintenance` categories with real drop-in scripts. Added git-checkout (with branch prompt) and port-check (with optional ports prompt).

### Fixed

- **`port-check.sh` crash under `set -euo pipefail`** - `grep -oP` returns exit 1 when no `pid=` info available (non-root); added `|| true` to prevent silent script death.
- **`make-scripts-executable.sh` operator precedence bug** - `git ... || cd ... && pwd` parsed as `(git || cd) && pwd`, causing REPO_ROOT to contain two paths with an embedded newline. Fixed with `{ ...; }` grouping.
- **`scan-secrets.sh` false positives** - the broad `[A-Za-z0-9/+=]{40}` AWS secret pattern matched `========` separator lines and file paths. Tightened to assignment-context only. Fixed shellcheck subshell counter bug.
- **`lib/stacks/_common.sh` corrupt shebang** - first line was `e out #!/usr/bin/env bash`; fixed.
- **`lib/tools/install-starship.sh`** - removed unused `YELLOW` variable (shellcheck SC2034).
- **`dashboard/start-dev.sh` config.php** - changed from hard-fail to auto-copy from `config.example.php` with warning.

---

## [v1.1.0] - Unreleased

### Added

- **`help.sh`** - root-level script listing all available scripts by domain with aligned descriptions.
- **`dashboard/start-dev.sh`** - template launcher for the PHP script-runner web UI (localhost-only).
- **`dashboard/index.php`** - router, API handlers, localhost guard, process management.
- **`dashboard/frontend.php`** - single-page HTML/CSS/JS UI with WSL path selector for multi-project support.
- **`dashboard/config.example.php`** - sample script registry with schema docs and project list.
- **`lib/tools/install-starship.sh`** - install Starship cross-shell prompt.
- **`lib/tools/uninstall-starship.sh`** - uninstall Starship.
- **`TODO_dashboard-plan.md`** - decoupling plan for porting the PHP dashboard into `dashboard/`.

### Changed

- **Renamed `lib/setup/` → `lib/tools/`** - clearer name for tool installer scripts.
- **Moved `sync-env.sh`** from `lib/setup/` to `lib/dev/` - it's a dev workflow template, not a tool installer.

### Fixed

- **`((var++))` crash under `set -e`** -`health-check-remote.sh` and `secrets-manager-health-check.sh` used post-increment arithmetic that returns exit status 1 when the counter is 0, aborting the script on the first check. Replaced with `$((var + 1))`.
- **`lint-all.sh` false failures on deleted files** -`git ls-files` returns tracked-but-deleted files. The linter now skips files that no longer exist on disk.
- **`.env` sourced as shell code** -`stacks/_common.sh`, `aws-cli.sh`, and `terraform.sh` used `source .env` which executes arbitrary shell commands. Replaced with safe `while IFS='=' read` key-value parsing.
- **Secrets printed to terminal** -`amplify-variables-set.sh` printed raw variable values (including DB passwords, API keys) during set operations. Values are now masked as `****(N chars)`.
- **`start-dev.sh` force-killed any process without checks** -Port cleanup now identifies the process name and owner before killing, and only kills processes owned by the current user.
- **`lint-all.sh --fix` applied patches silently** -Now prompts for confirmation before auto-applying shellcheck fixes via `git apply`.
- **`sed -i` broke on macOS** -`start-dev.sh` and `uninstall-kiro-cli.sh` used GNU `sed -i` which fails on BSD sed. Added platform branching for macOS compatibility.
- **`grep -P` broke on macOS** -`docker-cleanup.sh` used Perl-compatible regex not available on macOS. Replaced with portable `sed -n` equivalents.
- **`date +%s%N` timing showed 0.0s on macOS** -`stacks/_common.sh`, `preflight-checks.sh`, and all stacks preflight scripts divided by 1000000 assuming nanoseconds. macOS `date` doesn't support `%N`, so the fallback to seconds produced 0. Added `_goat_now()` helper with nanosecond detection and correct math for both formats.
- **CRLF line endings** -All files converted from Windows CRLF to Unix LF. Added `.gitattributes` with `* text=auto eol=lf` to enforce LF for all future checkouts regardless of `core.autocrlf`.

### Removed

- **Grok CLI scripts** -Removed `install-grok.sh` and `uninstall-grok.sh`. The upstream `@vibe-kit/grok-cli` package is unmaintained and broken (xAI deprecated the live search API on 2026-01-12, returning HTTP 410).
- **`lib/setup/install-bats.sh`** - deprecated shim that redirected to `install-bats-core.sh`.
- **`lib/maintenance/verify-checksums.sh`** - verified against a SHA-256 manifest that didn't exist.
- **`lib/maintenance/update-all.sh`** - thin wrapper around `git pull --rebase` + `make-scripts-executable.sh`.
- **`lib/dev/dev-logs.sh`** - tightly coupled to `start-dev.sh` service layout.
- **`lib/codegen/generate-api-client.sh`** - thin `npx openapi-generator-cli` wrapper.

### Documentation

- Removed stale Grok references from `README.md` and `docs/code-map.md`.
- Fixed script counts in `code-map.md` (ai-cli: 17→15, maintenance: 6→7, setup: 3→5).
- Added missing scripts to `README.md` tables: 5 maintenance scripts, `sync-env.sh`, `install-bats-core.sh`, `docker-cleanup.sh`, `docker-logs.sh`, `db-reset.sh`, `port-check.sh`.
- Added root `preflight-checks.sh` to `code-map.md` (was missing entirely).
- Fixed `gpu-check.sh` description -detects NVIDIA only, not Apple Silicon.
- Added two new footguns to `docs/footguns.md`: `((var++))` under `set -e`, and missing `show_help()` gap.
- Added `.claude/plans/`, `.claude/memory/`, `*.bak`, `.terraform/`, `*.tfstate*`, `.env.production` to `.gitignore`.

---

## [v1.0.0] -2026-02-26

Initial tagged release. Full library of reusable shell scripts organized by domain.

### Added

#### AI CLI (`lib/ai-cli/`)
- Shared library (`_common.sh`) -platform detection (macOS, Linux, WSL, Git Bash), npm helpers, WSL PATH sanitization, `command_exists()`, `verify_native_binary()`.
- Installers and uninstallers for 8 AI coding assistants: Claude Code, OpenAI Codex, Cursor Agent, Gemini CLI, GitHub Copilot CLI, Grok CLI, Kilo Code, Kiro CLI.

#### AWS (`lib/aws/`)
- `aws-cli.sh` -AWS CLI wrapper with profile/region management and SSO login.
- `terraform.sh` -Terraform init/plan/apply/destroy with S3 backend config.
- `deploy-ecr-ecs.sh` -Docker build → ECR push → ECS redeploy pipeline.
- `s3-sync.sh` -Sync build artifacts to S3 bucket.
- `cloudfront-invalidate.sh` -Invalidate CloudFront distribution cache.
- `secrets-manager-get.sh`, `secrets-manager-set.sh`, `secrets-manager-health-check.sh` -Secrets Manager CRUD and health checks.
- `amplify-health-check.sh`, `amplify-variables-get.sh`, `amplify-variables-set.sh` -Amplify environment variable management.

#### Code Generation (`lib/codegen/`)
- `generate-code-map.sh` -Generate annotated directory tree or deep file-contents map.
- `generate-api-client.sh` -Generate TypeScript API client from OpenAPI spec.

#### Development (`lib/dev/`)
- `start-dev.sh` -Start local dev environment (Docker + app server).
- `dev-logs.sh` -Tail and aggregate development logs.
- `docker-cleanup.sh` -Prune unused Docker resources.
- `docker-logs.sh` -Tail Docker Compose service logs.
- `db-reset.sh` -Drop/create/migrate/seed database.
- `health-check-localdev.sh` -Verify local services are running.
- `health-check-remote.sh` -Check remote AWS infrastructure health.
- `api-load-test.sh` -Simple HTTP load testing with curl.
- `gpu-check.sh` -Detect NVIDIA GPU availability.
- `port-check.sh` -Check port listeners, show PID/process.

#### Maintenance (`lib/maintenance/`)
- `git-cleanup.sh` -Delete merged local branches.
- `lint-all.sh` -Run `bash -n` + `shellcheck` on all scripts, with optional `--fix` mode.
- `make-scripts-executable.sh` -`chmod +x` all `.sh` files.
- `remove-zone-identifier.sh` -Remove Windows Zone.Identifier ADS files.
- `scan-secrets.sh` -Scan for accidentally committed secrets.
- `update-all.sh` -`git pull --rebase` + restore executable bits.
- `verify-checksums.sh` -Verify file integrity via SHA-256 manifest.

#### Setup (`lib/setup/`)
- `install-bats-core.sh` -Install bats-core test framework.
- `install-bats.sh` -Compatibility shim → `install-bats-core.sh`.
- `install-ollama.sh` -Install Ollama for local LLM inference.
- `uninstall-ollama.sh` -Uninstall Ollama.
- `sync-env.sh` -Copy `.env.example` → `.env` where missing.

#### Stacks (`lib/stacks/`)
- Shared library (`_common.sh`) -colors, symbols, counters, `step`/`pass`/`fail`/`skip`/`warn` helpers, `log_info`/`log_ok`, `PROJECT_ROOT` detection, `.env` loading.
- **Go** -`db-migrate-rollback.sh`, `rebuild-database.sh`, `seed-data.sh`.
- **Node.js** -`dependencies-install.sh`, `dependencies-update.sh`, `preflight-checks.sh`, `setup.sh`, `verify.sh`.
- **PHP** -`dependencies-install.sh`, `dependencies-update.sh`, `preflight-checks.sh`, `setup.sh`, `verify.sh`, `check-complexity.php`.
- **Python** -`dependencies-install.sh`, `dependencies-update.sh`, `preflight-checks.sh`, `setup.sh`, `verify.sh`.

#### Project Root
- `preflight-checks.sh` -Project-wide validation entry point (shebang, strict mode, syntax, shellcheck, executable bit, help flags, template config).

#### Tests (`tests/`)
- Convention tests: shebang, strict mode, syntax, shellcheck, executable bit, help flag, template config.
- Common library tests: `ai-cli-common.bats`, `stacks-common.bats`.
- Script tests: `codegen.bats`, `maintenance.bats`, `preflight.bats`.
- `test_helper.bash` -Shared test configuration and exception lists.

#### Documentation
- `README.md` -Full script reference with tables per domain.
- `CLAUDE.md`, `AGENTS.md`, `GEMINI.md` -AI agent instruction files.
- `docs/code-map.md` -Annotated repository tree.
- `docs/footguns.md` -Cross-domain gotchas (strict mode exceptions, WSL PATH, logging paradigms, source patterns, template defaults).
- `docs/bats-core.md` -Bats test framework documentation.
- `.github/instructions/` -Domain-specific coding instructions (shell conventions, ai-cli, aws, dev, stacks).
