# Code Map

Repository tree with annotations. Most scripts live under `lib/`; `help.sh` and `preflight-checks.sh` live at the repo root.

```
lib/
├── ai-cli/                          # AI coding assistant installers/uninstallers (15 scripts)
│   ├── _common.sh                   # Shared library: platform detection, npm helpers, WSL sanitization
│   ├── install-claude.sh            # Claude Code installer
│   ├── install-codex.sh             # OpenAI Codex installer
│   ├── install-cursor-agent.sh      # Cursor Agent installer
│   ├── install-gemini-cli.sh        # Gemini CLI installer
│   ├── install-github-copilot.sh    # GitHub Copilot CLI installer
│   ├── install-kilo.sh             # Kilo Code installer
│   ├── install-kiro-cli.sh         # Kiro CLI installer
│   ├── uninstall-claude.sh
│   ├── uninstall-codex.sh
│   ├── uninstall-cursor-agent.sh
│   ├── uninstall-gemini-cli.sh
│   ├── uninstall-github-copilot.sh
│   ├── uninstall-kilo.sh
│   └── uninstall-kiro-cli.sh
│
├── aws/                             # AWS infrastructure wrappers (11 scripts, all templates)
│   ├── amplify-health-check.sh      # Verify Amplify env vars are set
│   ├── amplify-variables-get.sh     # Dump Amplify env vars
│   ├── amplify-variables-set.sh     # Set Amplify env vars from .env
│   ├── aws-cli.sh                   # AWS CLI install/upgrade, SSO login
│   ├── cloudfront-invalidate.sh     # Invalidate CloudFront distribution cache (uses [invalidate] prefix)
│   ├── deploy-ecr-ecs.sh           # Build → ECR push → ECS redeploy (uses [deploy] log prefix)
│   ├── s3-sync.sh                   # Sync build artifacts to S3 bucket (uses [s3-sync] prefix)
│   ├── secrets-manager-get.sh       # Fetch secrets by prefix
│   ├── secrets-manager-health-check.sh  # Verify required secrets exist
│   ├── secrets-manager-set.sh       # Create/update secrets
│   └── terraform.sh                 # Terraform init/plan/apply with S3 backend
│
├── codegen/                         # Code generation utilities (1 script)
│   └── generate-code-map.sh         # Directory tree / deep file-contents map (drop-in)
│
├── dev/                             # Local development workflow (10 scripts)
│   ├── api-load-test.sh             # HTTP load testing with curl (template)
│   ├── db-reset.sh                  # Drop/create/migrate/seed database (template)
│   ├── docker-cleanup.sh            # Prune unused Docker resources (drop-in)
│   ├── docker-logs.sh               # Tail Docker Compose service logs (template)
│   ├── gpu-check.sh                 # Detect GPU — NVIDIA (drop-in, omits -e)
│   ├── health-check-localdev.sh     # Verify local services (template, omits -e)
│   ├── health-check-remote.sh       # Check remote AWS health (template)
│   ├── port-check.sh                # Check port listeners, show PID/process (drop-in)
│   ├── start-dev.sh                 # Start local dev environment (template, omits -e)
│   └── sync-env.sh                  # Copy .env.example → .env where missing (template)
│
├── maintenance/                     # Repo housekeeping (5 scripts, all drop-in)
│   ├── git-cleanup.sh               # Delete merged local branches
│   ├── lint-all.sh                  # Run bash -n + shellcheck on all scripts (omits -e)
│   ├── make-scripts-executable.sh   # chmod +x all .sh files
│   ├── remove-zone-identifier.sh    # Remove Windows Zone.Identifier ADS files
│   └── scan-secrets.sh              # Scan for accidentally committed secrets
│
├── tools/                           # Tool installation (5 scripts, all drop-in)
│   ├── install-bats-core.sh         # Install bats-core test framework
│   ├── install-ollama.sh            # Install Ollama for local LLM inference
│   ├── install-starship.sh          # Install Starship cross-shell prompt
│   ├── uninstall-ollama.sh          # Uninstall Ollama
│   └── uninstall-starship.sh        # Uninstall Starship
│
└── stacks/                          # Language-specific setup, deps, quality gates
    ├── _common.sh                   # Shared library: colors, symbols, counters, step/pass/fail,
    │                                #   log_info/log_ok, PROJECT_ROOT, .env loading
    ├── go/                          # Go database management (3 scripts)
    │   ├── db-migrate-rollback.sh   # Safe migration rollback with backup
    │   ├── rebuild-database.sh      # Drop tables, migrate, seed
    │   └── seed-data.sh             # Seed development data
    ├── node/                        # Node.js project lifecycle (5 scripts)
    │   ├── dependencies-install.sh  # Install from lockfile (npm ci / yarn / pnpm)
    │   ├── dependencies-update.sh   # Update deps + audit + smoke test
    │   ├── preflight-checks.sh      # Quality gates: eslint, tsc, jest/vitest, Docker Compose
    │   ├── setup.sh                 # First-time project setup
    │   └── verify.sh                # Verify Node.js tools installed (omits -e)
    ├── php/                         # PHP project lifecycle (6 scripts)
    │   ├── check-complexity.php     # Cyclomatic complexity analyzer (PHP, drop-in)
    │   ├── dependencies-install.sh  # Install from composer.lock
    │   ├── dependencies-update.sh   # Update deps + audit + smoke test
    │   ├── preflight-checks.sh      # Quality gates: CS-Fixer, PHPStan, PHPMD, PHPUnit
    │   ├── setup.sh                 # First-time project setup
    │   └── verify.sh                # Verify PHP tools installed (omits -e)
    └── python/                      # Python project lifecycle (5 scripts)
        ├── dependencies-install.sh  # Create venv + pip install
        ├── dependencies-update.sh   # Upgrade packages + audit
        ├── preflight-checks.sh      # Quality gates: ruff, pytest, Docker Compose
        ├── setup.sh                 # First-time project setup
        └── verify.sh                # Verify Python tools installed (omits -e)
```

**Root:** `help.sh` — categorized listing of all available scripts (repo root, not under `lib/`)
**Root:** `preflight-checks.sh` — project-wide validation entry point (repo root, not under `lib/`)

**Dashboard** (`dashboard/`):
- `start-dev.sh` — PHP dashboard launcher (template)
- `index.php` — Router, API handlers, localhost guard, process management
- `frontend.php` — Single-page HTML/CSS/JS UI (inline, no build step)
- `config.example.php` — Sample script registry with schema docs

**Total:** 69 shell scripts + 4 PHP files across `lib/`, root, and `dashboard/`
