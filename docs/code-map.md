# Code Map

Repository tree with annotations. Most scripts live under `lib/`; `help.sh` and `preflight-checks.sh` remain at root as delegating entrypoints.

```
lib/
├── ai-cli/                          # AI coding assistant installers/uninstallers
│   ├── _common.sh                   # Shared ai-cli library (platform + npm helpers + WSL path guard)
│   ├── install-*.sh
│   └── uninstall-*.sh
│
├── aws/                             # AWS wrappers (templates)
│   ├── aws-cli.sh                   # AWS CLI install/login helpers
│   ├── terraform.sh                 # Terraform init/plan/apply wrapper
│   ├── s3-sync.sh                   # Sync artifacts to S3
│   ├── cloudfront-invalidate.sh     # CloudFront invalidation
│   ├── secrets-manager-get.sh       # Fetch secrets
│   ├── secrets-manager-set.sh       # Set secrets
│   ├── secrets-manager-health-check.sh
│   └── health-check.sh             # Remote AWS infrastructure health checks
│
├── codegen/
│   └── generate-code-map.sh         # Directory tree / deep map generator
│
├── docker/
│   ├── down.sh                     # Stop docker compose services
│   ├── restart.sh                  # Restart docker compose services
│   ├── logs-tail.sh                 # Tail docker compose logs
│   ├── prune.sh                     # Prune docker resources
│   ├── network-heal.sh             # Docker network diagnostics/prune
│   ├── mount-doctor.sh             # Container mount diagnostics
│   └── up.sh                       # Start docker compose services
│
├── health/
│   ├── check-api-auth.sh           # Bearer-token auth probe
│   ├── check-gpu.sh                 # GPU detection
│   ├── load-test.sh                 # API load testing
│   └── port-check.sh                # Port listener diagnostics
│
├── maintenance/                     # Repo housekeeping
│   ├── git-cleanup.sh
│   ├── make-scripts-executable.sh
│   ├── remove-zone-identifier.sh
│   └── scan-secrets.sh
│
├── stacks/                          # Stack-specific canonical layer
│   ├── _common.sh
│   ├── go/
│   │   ├── db-migrate-rollback.sh
│   │   ├── rebuild-database.sh
│   │   └── seed-data.sh
│   ├── node/
│   │   ├── dependencies-install.sh
│   │   ├── dependencies-update.sh
│   │   ├── preflight-checks.sh
│   │   ├── setup.sh
│   │   └── verify.sh
│   ├── php/
│   │   ├── check-complexity.php
│   │   ├── dependencies-install.sh
│   │   ├── dependencies-update.sh
│   │   ├── preflight-checks.sh
│   │   ├── setup.sh
│   │   └── verify.sh
│   ├── rust/
│   │   ├── dependencies-install.sh
│   │   ├── dependencies-update.sh
│   │   ├── preflight-checks.sh
│   │   ├── setup.sh
│   │   └── verify.sh
│   └── python/
│       ├── dependencies-install.sh
│       ├── dependencies-update.sh
│       ├── preflight-checks.sh
│       ├── setup.sh
│       └── verify.sh
│
├── tools/
│   ├── install-bats-core.sh
│   ├── install-ollama.sh
│   ├── install-starship.sh
│   ├── uninstall-ollama.sh
│   └── uninstall-starship.sh
│
└── workflow/
    ├── help-index.sh                # Categorized help and keyword search
    ├── git-change-branch.sh
    ├── git-status.sh
    └── sync-env.sh
```

Root entrypoints:
- `help.sh` -> delegates to `lib/workflow/help-index.sh`
- `preflight-checks.sh` - standalone repo-level quality gate

Dashboard (`dashboard/`):
- `start-dev.sh` - PHP dashboard launcher
- `index.php` - Router/API handlers
- `frontend.php` - UI
- `config.example.php` - Sample config
- process management uses shell `kill` helpers (no ext-posix dependency)
