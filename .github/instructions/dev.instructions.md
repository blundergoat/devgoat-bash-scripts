---
applyTo: "lib/docker/**,lib/health/**,lib/workflow/**,lib/maintenance/**,lib/tools/**,lib/codegen/**"
---

# docker / workflow / health / maintenance / tools / codegen Domains

These directories share the same self-contained script pattern. No shared library - each script defines its own colors and logging helpers inline.

## Logging Pattern

Standalone inline functions, similar to aws scripts:
```bash
log()     { echo -e "${BLUE}[info]${NC} $*"; }
success() { echo -e "${GREEN}[ok]${NC} $*"; }
warn()    { echo -e "${YELLOW}[warn]${NC} $*"; }
error()   { echo -e "${RED}[error]${NC} $*"; exit 1; }
```

Function names and tag styles vary by script - match the existing pattern in the file you're editing.

## Strict Mode Exceptions

| Script | Mode | Reason |
|--------|------|--------|
| `health/check-gpu.sh` | `set -uo pipefail` | Probes multiple GPU backends; some checks can fail while still allowing final status reporting |

All other scripts in these directories use `set -euo pipefail`.

## Notable Scripts

### `codegen/generate-code-map.sh`
Drop-in script (no CONFIGURATION block). Supports `--path`, `--mode`, `--deep` flags.

### `maintenance/make-scripts-executable.sh`
Drop-in. Supports `--dry-run`. Targets `scripts/` directory by default in the consuming project.

### `docker/prune.sh`
Drop-in. Prunes containers, images, volumes, and networks. Supports `--dry-run` and `--all` (aggressive image prune).

### `health/port-check.sh`
Drop-in. Checks port listeners with `ss` (Linux) or `lsof` (macOS). Supports `--kill` with confirmation.

### `workflow/sync-env.sh`
Template. Finds `.env.example` files and copies to `.env` if missing. Supports `--force` and `--diff`.

## Template vs Drop-in

| Directory | Templates | Drop-ins |
|-----------|-----------|----------|
| `docker/` | - | down, logs-tail, mount-doctor, network-heal, prune, restart, up |
| `health/` | - | check-api-auth, check-gpu, load-test, port-check |
| `workflow/` | - | git-change-branch, git-status, help-index, sync-env |
| `maintenance/` | - | git-cleanup, make-scripts-executable, remove-zone-identifier, scan-secrets |
| `tools/` | - | install-bats-core, install-ollama, uninstall-ollama, install-starship, uninstall-starship |
| `codegen/` | - | generate-code-map |
