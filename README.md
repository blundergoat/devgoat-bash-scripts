# devgoat-bash-scripts

A collection of reusable shell scripts for project setup, development workflows, AWS infrastructure, database management, code quality, and maintenance automation. Consolidated from battle-tested scripts used across multiple production projects.

## Directory Overview

All scripts live under `lib/` to keep the repo root clean. Two root-level tools - `help.sh` (script listing) and `preflight-checks.sh` (quality gate) - live at the repo root for quick access.

| Directory | Description |
|---|---|
| [`lib/ai-cli/`](#ai-cli) | AI coding assistant installers and uninstallers |
| [`lib/aws/`](#aws) | AWS CLI, Terraform, ECR/ECS deploy, Secrets Manager, Amplify |
| [`lib/codegen/`](#codegen) | Code map generator |
| [`dashboard/`](#dashboard) | PHP script-runner web UI with project switcher |
| [`lib/dev/`](#dev) | Local dev server, logs, health checks, load testing |
| [`lib/maintenance/`](#maintenance) | Repo housekeeping (permissions, Zone.Identifier cleanup) |
| [`lib/tools/`](#tools) | Tool installers (Ollama, Starship, bats-core) |
| [`lib/stacks/`](#stacks) | Language-specific setup, deps, quality gates (PHP, Python, Go) |

## Quick Start

```bash
git clone https://github.com/blundergoat/devgoat-bash-scripts.git
cd devgoat-bash-scripts

# See all available scripts
./help.sh

# Run any script directly
./lib/ai-cli/install-claude.sh
./lib/dev/gpu-check.sh
./lib/maintenance/remove-zone-identifier.sh /path/to/clean

# Copy a whole stack into your project
cp -r lib/stacks/php/ my-project/scripts/
```

## Drop-in vs Template Scripts

Scripts fall into two categories:

**Drop-in** - Run as-is with no configuration. These are standalone tools:
- All `lib/ai-cli/` installers/uninstallers
- `lib/codegen/generate-code-map.sh`
- `lib/stacks/php/check-complexity.php`
- `lib/maintenance/make-scripts-executable.sh`
- `lib/maintenance/remove-zone-identifier.sh`

**Template** - Require a `# ---- CONFIGURATION ----` block at the top with project-specific values. Copy into your project and fill in the variables:
- All `lib/aws/` scripts
- All `lib/stacks/` scripts (except `check-complexity.php`)
- All `lib/dev/` scripts (except `sync-env.sh`)

Template scripts use environment variable fallbacks (`${VAR:-default}`) so you can either edit the defaults in the script or override them via environment variables.

## Script Categories

### ai-cli

Installers and uninstallers for AI coding assistants. All scripts handle platform detection (macOS, Linux, WSL, Git Bash) via the shared `_common.sh` library.

**Prerequisites:** Node.js 18+ (auto-installed if missing for npm-based tools)

| Script | Tool |
|---|---|
| `install-claude.sh` / `uninstall-claude.sh` | [Claude Code](https://claude.ai/claude-code) |
| `install-codex.sh` / `uninstall-codex.sh` | [OpenAI Codex](https://github.com/openai/codex) |
| `install-cursor-agent.sh` / `uninstall-cursor-agent.sh` | [Cursor Agent](https://cursor.com) |
| `install-gemini-cli.sh` / `uninstall-gemini-cli.sh` | [Gemini CLI](https://github.com/google/gemini-cli) |
| `install-github-copilot.sh` / `uninstall-github-copilot.sh` | [GitHub Copilot CLI](https://github.com/github/copilot) |
| `install-kilo.sh` / `uninstall-kilo.sh` | [Kilo Code](https://kilocode.ai) |
| `install-kiro-cli.sh` / `uninstall-kiro-cli.sh` | [Kiro CLI](https://kiro.dev) |


### aws

AWS infrastructure wrappers. Each script has a configuration block for AWS profile, region, and resource names.

**Prerequisites:** AWS CLI v2, valid AWS SSO or IAM credentials

| Script | Purpose |
|---|---|
| `aws-cli.sh` | AWS CLI install/upgrade, SSO login, profile management |
| `terraform.sh` | Terraform init/plan/apply with S3 backend config |
| `deploy-ecr-ecs.sh` | Build Docker images, push to ECR, deploy to ECS |
| `secrets-manager-get.sh` | Fetch secrets by prefix from Secrets Manager |
| `secrets-manager-set.sh` | Create or update secrets in Secrets Manager |
| `secrets-manager-health-check.sh` | Verify all required secrets exist |
| `amplify-health-check.sh` | Verify Amplify environment variables are set |
| `amplify-variables-get.sh` | Dump Amplify environment variables |
| `amplify-variables-set.sh` | Set Amplify environment variables from `.env` |

### codegen

Code generation and analysis utilities.

| Script | Purpose | Type |
|---|---|---|
| `generate-code-map.sh` | Generate directory tree or deep file-contents map for a path | Drop-in |

### dashboard

PHP-based web UI for running project scripts from the browser. Localhost-only - the PHP guard returns HTTP 403 for any non-localhost request. Includes a WSL path selector for running scripts against any local project.

**Prerequisites:** PHP 8.1+ with posix extension, `script(1)` command

| File | Purpose | Type |
|---|---|---|
| `start-dev.sh` | Launch the PHP dashboard server on localhost | Template |
| `index.php` | Router, API handlers, localhost guard, process management | PHP |
| `frontend.php` | Single-page HTML/CSS/JS UI with project switcher | PHP |
| `config.example.php` | Sample script registry and project list | PHP |

### dev

Local development workflow scripts.

| Script | Purpose |
|---|---|
| `start-dev.sh` | Start local dev environment (Docker + app server) |
| `health-check-localdev.sh` | Verify local services are running correctly |
| `health-check-remote.sh` | Check remote AWS infrastructure health |
| `api-load-test.sh` | Simple HTTP load testing with `curl` |
| `gpu-check.sh` | Detect GPU availability (NVIDIA) |
| `docker-cleanup.sh` | Prune unused Docker resources |
| `docker-logs.sh` | Tail Docker Compose service logs |
| `db-reset.sh` | Drop/create/migrate/seed database |
| `port-check.sh` | Check port listeners, show PID/process |
| `sync-env.sh` | Copy `.env.example` to `.env` where missing |

### maintenance

Repository housekeeping tools.

| Script | Purpose | Type |
|---|---|---|
| `git-cleanup.sh` | Delete merged local branches | Drop-in |
| `lint-all.sh` | Run `bash -n` + `shellcheck` on all scripts | Drop-in |
| `make-scripts-executable.sh` | `chmod +x` all `.sh` files | Drop-in |
| `remove-zone-identifier.sh` | Remove Windows Zone.Identifier ADS files | Drop-in |
| `scan-secrets.sh` | Scan for accidentally committed secrets | Drop-in |

### tools

Tool installation scripts.

| Script | Purpose |
|---|---|
| `install-bats-core.sh` | Install bats-core test framework |
| `install-ollama.sh` | Install Ollama for local LLM inference |
| `install-starship.sh` | Install Starship cross-shell prompt |
| `uninstall-ollama.sh` | Uninstall Ollama |
| `uninstall-starship.sh` | Uninstall Starship |

### stacks

Language-specific scripts organized by stack. Each stack is independently copyable - grab just the directory you need. All scripts source `lib/stacks/_common.sh` for shared helpers, colors, and `.env` loading.

#### stacks/php

PHP project setup, dependency management, and quality gates.

**Prerequisites:** PHP 8.2+, Composer

| Script | Purpose |
|---|---|
| `setup.sh` | First-time PHP project setup (prerequisites, .env, composer install) |
| `verify.sh` | Verify PHP tools and dependencies are installed correctly |
| `dependencies-install.sh` | Install PHP dependencies from `composer.lock` |
| `dependencies-update.sh` | Update PHP dependencies + security audit + PHPUnit smoke test |
| `preflight-checks.sh` | PHP quality gates: CS-Fixer, PHPStan, PHPMD, PHPUnit, coverage, mutation |
| `check-complexity.php` | Measure PHP function cyclomatic complexity (token-based, drop-in) |

#### stacks/python

Python project setup, dependency management, and quality gates.

**Prerequisites:** Python 3.12+, pip3

| Script | Purpose |
|---|---|
| `setup.sh` | First-time Python project setup (prerequisites, .env, venv, pip install) |
| `verify.sh` | Verify Python tools, venv, and dependencies are installed correctly |
| `dependencies-install.sh` | Create venv + install from `requirements.txt` |
| `dependencies-update.sh` | Upgrade pip packages + audit + syntax check |
| `preflight-checks.sh` | Python quality gates: syntax check, ruff, pytest, Docker Compose |

#### stacks/go

Go project database management scripts using `golang-migrate` and raw SQL.

**Prerequisites:** Go, `golang-migrate` CLI, PostgreSQL client tools

| Script | Purpose |
|---|---|
| `rebuild-database.sh` | Drop all tables, run migrations, seed data |
| `db-migrate-rollback.sh` | Safe migration rollback with backup and dry-run |
| `seed-data.sh` | Seed database with sample/development data |

## AI Agent Context

Context files for AI coding assistants: `CLAUDE.md` (Claude Code), `AGENTS.md` (GitHub Copilot / generic), `GEMINI.md` (Gemini CLI).
Domain-specific instructions: `.github/instructions/`. Cross-cutting docs: `docs/`.

## Contributing

1. Fork the repo
2. Create a feature branch
3. Use kebab-case for all new script filenames
4. Add `set -euo pipefail` to all bash scripts
5. Include a help flag (`--help` or `-h`)
6. For template scripts, put all project-specific values in a `# ---- CONFIGURATION ----` block at the top
7. Test on both macOS and Linux where possible
8. Submit a PR

## License

[MIT](LICENSE)
