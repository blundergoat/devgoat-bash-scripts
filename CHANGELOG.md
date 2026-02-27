# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).

---

## [v1.1.0] — Unreleased

### Fixed

- **`((var++))` crash under `set -e`** — `health-check-remote.sh` and `secrets-manager-health-check.sh` used post-increment arithmetic that returns exit status 1 when the counter is 0, aborting the script on the first check. Replaced with `$((var + 1))`.
- **`lint-all.sh` false failures on deleted files** — `git ls-files` returns tracked-but-deleted files. The linter now skips files that no longer exist on disk.
- **`.env` sourced as shell code** — `stacks/_common.sh`, `aws-cli.sh`, and `terraform.sh` used `source .env` which executes arbitrary shell commands. Replaced with safe `while IFS='=' read` key-value parsing.
- **Secrets printed to terminal** — `amplify-variables-set.sh` printed raw variable values (including DB passwords, API keys) during set operations. Values are now masked as `****(N chars)`.
- **`start-dev.sh` force-killed any process without checks** — Port cleanup now identifies the process name and owner before killing, and only kills processes owned by the current user.
- **`lint-all.sh --fix` applied patches silently** — Now prompts for confirmation before auto-applying shellcheck fixes via `git apply`.
- **`sed -i` broke on macOS** — `start-dev.sh` and `uninstall-kiro-cli.sh` used GNU `sed -i` which fails on BSD sed. Added platform branching for macOS compatibility.
- **`grep -P` broke on macOS** — `docker-cleanup.sh` used Perl-compatible regex not available on macOS. Replaced with portable `sed -n` equivalents.
- **`date +%s%N` timing showed 0.0s on macOS** — `stacks/_common.sh`, `preflight-checks.sh`, and all stacks preflight scripts divided by 1000000 assuming nanoseconds. macOS `date` doesn't support `%N`, so the fallback to seconds produced 0. Added `_goat_now()` helper with nanosecond detection and correct math for both formats.
- **CRLF line endings** — All files converted from Windows CRLF to Unix LF. Added `.gitattributes` with `* text=auto eol=lf` to enforce LF for all future checkouts regardless of `core.autocrlf`.

### Removed

- **Grok CLI scripts** — Removed `install-grok.sh` and `uninstall-grok.sh`. The upstream `@vibe-kit/grok-cli` package is unmaintained and broken (xAI deprecated the live search API on 2026-01-12, returning HTTP 410).

### Documentation

- Removed stale Grok references from `README.md` and `docs/code-map.md`.
- Fixed script counts in `code-map.md` (ai-cli: 17→15, maintenance: 6→7, setup: 3→5).
- Added missing scripts to `README.md` tables: 5 maintenance scripts, `sync-env.sh`, `install-bats-core.sh`, `docker-cleanup.sh`, `docker-logs.sh`, `db-reset.sh`, `port-check.sh`.
- Added root `preflight-checks.sh` to `code-map.md` (was missing entirely).
- Fixed `gpu-check.sh` description — detects NVIDIA only, not Apple Silicon.
- Added two new footguns to `docs/footguns.md`: `((var++))` under `set -e`, and missing `show_help()` gap.
- Added `.claude/plans/`, `.claude/memory/`, `*.bak`, `.terraform/`, `*.tfstate*`, `.env.production` to `.gitignore`.

---

## [v1.0.0] — 2026-02-26

Initial tagged release. Full library of reusable shell scripts organized by domain.

### Added

#### AI CLI (`lib/ai-cli/`)
- Shared library (`_common.sh`) — platform detection (macOS, Linux, WSL, Git Bash), npm helpers, WSL PATH sanitization, `command_exists()`, `verify_native_binary()`.
- Installers and uninstallers for 8 AI coding assistants: Claude Code, OpenAI Codex, Cursor Agent, Gemini CLI, GitHub Copilot CLI, Grok CLI, Kilo Code, Kiro CLI.

#### AWS (`lib/aws/`)
- `aws-cli.sh` — AWS CLI wrapper with profile/region management and SSO login.
- `terraform.sh` — Terraform init/plan/apply/destroy with S3 backend config.
- `deploy-ecr-ecs.sh` — Docker build → ECR push → ECS redeploy pipeline.
- `s3-sync.sh` — Sync build artifacts to S3 bucket.
- `cloudfront-invalidate.sh` — Invalidate CloudFront distribution cache.
- `secrets-manager-get.sh`, `secrets-manager-set.sh`, `secrets-manager-health-check.sh` — Secrets Manager CRUD and health checks.
- `amplify-health-check.sh`, `amplify-variables-get.sh`, `amplify-variables-set.sh` — Amplify environment variable management.

#### Code Generation (`lib/codegen/`)
- `generate-code-map.sh` — Generate annotated directory tree or deep file-contents map.
- `generate-api-client.sh` — Generate TypeScript API client from OpenAPI spec.

#### Development (`lib/dev/`)
- `start-dev.sh` — Start local dev environment (Docker + app server).
- `dev-logs.sh` — Tail and aggregate development logs.
- `docker-cleanup.sh` — Prune unused Docker resources.
- `docker-logs.sh` — Tail Docker Compose service logs.
- `db-reset.sh` — Drop/create/migrate/seed database.
- `health-check-localdev.sh` — Verify local services are running.
- `health-check-remote.sh` — Check remote AWS infrastructure health.
- `api-load-test.sh` — Simple HTTP load testing with curl.
- `gpu-check.sh` — Detect NVIDIA GPU availability.
- `port-check.sh` — Check port listeners, show PID/process.

#### Maintenance (`lib/maintenance/`)
- `git-cleanup.sh` — Delete merged local branches.
- `lint-all.sh` — Run `bash -n` + `shellcheck` on all scripts, with optional `--fix` mode.
- `make-scripts-executable.sh` — `chmod +x` all `.sh` files.
- `remove-zone-identifier.sh` — Remove Windows Zone.Identifier ADS files.
- `scan-secrets.sh` — Scan for accidentally committed secrets.
- `update-all.sh` — `git pull --rebase` + restore executable bits.
- `verify-checksums.sh` — Verify file integrity via SHA-256 manifest.

#### Setup (`lib/setup/`)
- `install-bats-core.sh` — Install bats-core test framework.
- `install-bats.sh` — Compatibility shim → `install-bats-core.sh`.
- `install-ollama.sh` — Install Ollama for local LLM inference.
- `uninstall-ollama.sh` — Uninstall Ollama.
- `sync-env.sh` — Copy `.env.example` → `.env` where missing.

#### Stacks (`lib/stacks/`)
- Shared library (`_common.sh`) — colors, symbols, counters, `step`/`pass`/`fail`/`skip`/`warn` helpers, `log_info`/`log_ok`, `PROJECT_ROOT` detection, `.env` loading.
- **Go** — `db-migrate-rollback.sh`, `rebuild-database.sh`, `seed-data.sh`.
- **Node.js** — `dependencies-install.sh`, `dependencies-update.sh`, `preflight-checks.sh`, `setup.sh`, `verify.sh`.
- **PHP** — `dependencies-install.sh`, `dependencies-update.sh`, `preflight-checks.sh`, `setup.sh`, `verify.sh`, `check-complexity.php`.
- **Python** — `dependencies-install.sh`, `dependencies-update.sh`, `preflight-checks.sh`, `setup.sh`, `verify.sh`.

#### Project Root
- `preflight-checks.sh` — Project-wide validation entry point (shebang, strict mode, syntax, shellcheck, executable bit, help flags, template config).

#### Tests (`tests/`)
- Convention tests: shebang, strict mode, syntax, shellcheck, executable bit, help flag, template config.
- Common library tests: `ai-cli-common.bats`, `stacks-common.bats`.
- Script tests: `codegen.bats`, `maintenance.bats`, `preflight.bats`.
- `test_helper.bash` — Shared test configuration and exception lists.

#### Documentation
- `README.md` — Full script reference with tables per domain.
- `CLAUDE.md`, `AGENTS.md`, `GEMINI.md` — AI agent instruction files.
- `docs/code-map.md` — Annotated repository tree.
- `docs/footguns.md` — Cross-domain gotchas (strict mode exceptions, WSL PATH, logging paradigms, source patterns, template defaults).
- `docs/bats-core.md` — Bats test framework documentation.
- `.github/instructions/` — Domain-specific coding instructions (shell conventions, ai-cli, aws, dev, stacks).
