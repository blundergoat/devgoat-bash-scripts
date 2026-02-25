# Code Map

Repository tree with annotations. All scripts live under `lib/`.

```
lib/
├── ai-cli/                          # AI coding assistant installers/uninstallers (17 scripts)
│   ├── _common.sh                   # Shared library: platform detection, npm helpers, WSL sanitization
│   ├── install-claude.sh            # Claude Code installer
│   ├── install-codex.sh             # OpenAI Codex installer
│   ├── install-cursor-agent.sh      # Cursor Agent installer
│   ├── install-gemini-cli.sh        # Gemini CLI installer
│   ├── install-github-copilot.sh    # GitHub Copilot CLI installer
│   ├── install-grok.sh             # Grok CLI installer
│   ├── install-kilo.sh             # Kilo Code installer
│   ├── install-kiro-cli.sh         # Kiro CLI installer
│   ├── uninstall-claude.sh
│   ├── uninstall-codex.sh
│   ├── uninstall-cursor-agent.sh
│   ├── uninstall-gemini-cli.sh
│   ├── uninstall-github-copilot.sh
│   ├── uninstall-grok.sh
│   ├── uninstall-kilo.sh
│   └── uninstall-kiro-cli.sh
│
├── aws/                             # AWS infrastructure wrappers (9 scripts, all templates)
│   ├── amplify-health-check.sh      # Verify Amplify env vars are set
│   ├── amplify-variables-get.sh     # Dump Amplify env vars
│   ├── amplify-variables-set.sh     # Set Amplify env vars from .env
│   ├── aws-cli.sh                   # AWS CLI install/upgrade, SSO login
│   ├── deploy-ecr-ecs.sh           # Build → ECR push → ECS redeploy (uses [deploy] log prefix)
│   ├── secrets-manager-get.sh       # Fetch secrets by prefix
│   ├── secrets-manager-health-check.sh  # Verify required secrets exist
│   ├── secrets-manager-set.sh       # Create/update secrets
│   └── terraform.sh                 # Terraform init/plan/apply with S3 backend
│
├── codegen/                         # Code generation utilities (2 scripts)
│   ├── generate-api-client.sh       # TypeScript API client from OpenAPI spec (template)
│   └── generate-code-map.sh         # Directory tree / deep file-contents map (drop-in)
│
├── dev/                             # Local development workflow (6 scripts)
│   ├── api-load-test.sh             # HTTP load testing with curl (template)
│   ├── dev-logs.sh                  # Tail and aggregate dev logs (template)
│   ├── gpu-check.sh                 # Detect GPU — NVIDIA/Apple Silicon (drop-in, omits -e)
│   ├── health-check-localdev.sh     # Verify local services (template, omits -e)
│   ├── health-check-remote.sh       # Check remote AWS health (template)
│   └── start-dev.sh                 # Start local dev environment (template, omits -e)
│
├── maintenance/                     # Repo housekeeping (2 scripts, both drop-in)
│   ├── make-scripts-executable.sh   # chmod +x all .sh files
│   └── remove-zone-identifier.sh    # Remove Windows Zone.Identifier ADS files
│
├── setup/                           # Tool installation (2 scripts)
│   ├── install-ollama.sh            # Install Ollama for local LLM inference
│   └── uninstall-ollama.sh          # Uninstall Ollama
│
└── stacks/                          # Language-specific setup, deps, quality gates
    ├── _common.sh                   # Shared library: colors, symbols, counters, step/pass/fail,
    │                                #   log_info/log_ok, PROJECT_ROOT, .env loading
    ├── go/                          # Go database management (3 scripts)
    │   ├── db-migrate-rollback.sh   # Safe migration rollback with backup
    │   ├── rebuild-database.sh      # Drop tables, migrate, seed
    │   └── seed-data.sh             # Seed development data
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

**Total:** 52 files (50 shell scripts, 1 PHP script, 1 shared PHP file)
