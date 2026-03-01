# devgoat-bash-scripts

Reusable shell scripts for setup, diagnostics, deployments, and maintenance across mixed stacks (Go, Rust, PHP, Python, Node).

## Directory Overview

All scripts live under `lib/`. Root entrypoints:
- `./help.sh` -> delegates to `lib/workflow/help-index.sh`
- `./preflight-checks.sh` -> delegates to `lib/quality/preflight.sh`

| Directory | Purpose |
|---|---|
| `lib/workflow/` | High-level workflow entrypoints and git helpers |
| `lib/deps/` | Dependency manager and stack dependency dispatch helpers |
| `lib/docker/` | Docker operations (logs, prune) |
| `lib/health/` | Local/remote diagnostics, GPU/ports, load testing |
| `lib/quality/` | Repo/stack lint and preflight gates |
| `lib/aws/` | AWS deploy + infra + secrets wrappers |
| `lib/stacks/` | Stack-specific setup/deps/preflight/verify scripts |
| `lib/ai-cli/` | AI CLI installers/uninstallers |
| `lib/maintenance/` | Repo housekeeping scripts |
| `lib/tools/` | Local tool installers/uninstallers |
| `lib/codegen/` | Code map generation |

## Quick Start

```bash
git clone https://github.com/blundergoat/devgoat-bash-scripts.git
cd devgoat-bash-scripts

./help.sh
./preflight-checks.sh

# Examples
./lib/quality/lint-shell.sh
./lib/health/check-gpu.sh
./lib/aws/deploy.sh
```

## Migration Notes

Removed scripts (no replacement):
- `lib/aws/amplify-health-check.sh`
- `lib/aws/amplify-variables-get.sh`
- `lib/aws/amplify-variables-set.sh`
- `lib/maintenance/lint-all.sh`

## Script Families

### workflow

| Script | Purpose |
|---|---|
| `help-index.sh` | Categorized script index with keyword filtering |
| `sync-env.sh` | Copy `.env.example` to `.env` where missing |
| `git-change-branch.sh` | Branch switch helper (renamed from `git-checkout.sh`) |
| `git-status.sh` | Repository status helper |

### docker

| Script | Purpose |
|---|---|
| `restart.sh` | Restart Docker Compose services |
| `up.sh` | Start Docker Compose services |
| `down.sh` | Stop Docker Compose services |
| `prune.sh` | Prune unused Docker resources |
| `logs-tail.sh` | Tail Docker Compose logs |
| `network-heal.sh` | Docker network diagnostics and optional prune |
| `mount-doctor.sh` | Container mount diagnostics |

### health

| Script | Purpose |
|---|---|
| `check-api-auth.sh` | Basic bearer-token auth probe |
| `check-gpu.sh` | GPU availability checks |
| `port-check.sh` | Port listener checks |
| `load-test.sh` | API load testing |

### aws

| Script | Purpose |
|---|---|
| `aws-cli.sh` | AWS CLI install/login helpers |
| `terraform.sh` | Terraform wrapper |
| `s3-sync.sh` | Sync build artifacts to S3 |
| `cloudfront-invalidate.sh` | Invalidate CloudFront cache |
| `secrets-manager-get.sh` | Fetch secrets |
| `secrets-manager-set.sh` | Write secrets |
| `secrets-manager-health-check.sh` | Verify required secrets exist |
| `health-check.sh` | Remote AWS infrastructure health checks |

### stacks

`lib/stacks/` remains the canonical stack layer for:
- `node/`, `php/`, `python/`, `rust/` setup/dependencies/preflight/verify
- `go/` database utilities

### maintenance

| Script | Purpose |
|---|---|
| `git-cleanup.sh` | Delete merged local branches |
| `make-scripts-executable.sh` | Restore executable bits |
| `remove-zone-identifier.sh` | Remove Zone.Identifier files |
| `scan-secrets.sh` | Scan for accidentally committed secrets |

### tools

| Script | Purpose |
|---|---|
| `install-bats-core.sh` | Install bats-core |
| `install-ollama.sh` / `uninstall-ollama.sh` | Manage Ollama |
| `install-starship.sh` / `uninstall-starship.sh` | Manage Starship |

### codegen

| Script | Purpose |
|---|---|
| `generate-code-map.sh` | Generate an annotated repository tree |

### dashboard

| Script | Purpose |
|---|---|
| `dashboard/start-dev.sh` | Launch PHP dashboard UI |

Dashboard process management no longer depends on the PHP `ext-posix` extension.

## Testing

```bash
bash -n lib/path/to/script.sh
shellcheck lib/path/to/script.sh
./preflight-checks.sh
```

## License

[MIT](LICENSE)
