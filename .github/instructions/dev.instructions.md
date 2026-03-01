---
applyTo: "lib/dev/**,lib/maintenance/**,lib/tools/**,lib/codegen/**"
---

# dev / maintenance / tools / codegen Domains

These four directories share the same self-contained script pattern. No shared library — each script defines its own colors and logging helpers inline.

## Logging Pattern

Standalone inline functions, similar to aws scripts:
```bash
log()     { echo -e "${BLUE}[info]${NC} $*"; }
success() { echo -e "${GREEN}[ok]${NC} $*"; }
warn()    { echo -e "${YELLOW}[warn]${NC} $*"; }
error()   { echo -e "${RED}[error]${NC} $*"; exit 1; }
```

Function names and tag styles vary by script — match the existing pattern in the file you're editing.

## Strict Mode Exceptions

| Script | Mode | Reason |
|--------|------|--------|
| `dev/gpu-check.sh` | `set -uo pipefail` | Probes multiple GPU backends; some always fail |
| `dev/health-check-localdev.sh` | `set -uo pipefail` | Checks multiple services, reports combined status |
| `dev/start-dev.sh` | `set -uo pipefail` | Manages background processes with custom cleanup trap |
| `maintenance/lint-all.sh` | `set -uo pipefail` | Lints all scripts, must report all failures |

All other scripts in these directories use `set -euo pipefail`.

## Notable Scripts

### `dev/health-check-localdev.sh`
Redefines stacks-like helpers inline (`step`, `pass`, `fail`, `warn`, `section`, `probe`) rather than sourcing `_common.sh`. This is intentional — the script is a template meant to be copied into projects that don't have access to the stacks library. Do not refactor to source `_common.sh`.

### `dev/start-dev.sh`
Largest script in the repo (~580 lines). Manages Ollama, Python agent, Mercure hub, and PHP dev server as background processes. Uses a `cleanup` trap for graceful shutdown. The `env_default` helper reads from `.env` without exporting (respects PHP's `variables_order` limitation).

### `codegen/generate-code-map.sh`
Drop-in script (no CONFIGURATION block). Supports `--path`, `--mode`, `--deep` flags.

### `maintenance/make-scripts-executable.sh`
Drop-in. Supports `--dry-run`. Targets `scripts/` directory by default in the consuming project.

### `maintenance/lint-all.sh`
Drop-in. Runs `bash -n` + `shellcheck` on all git-tracked `.sh` files. Supports `--fix` and `--syntax-only`. Uses `set -uo pipefail` to accumulate failures.

### `dev/docker-cleanup.sh`
Drop-in. Prunes containers, images, volumes, and networks. Supports `--dry-run` and `--all` (aggressive image prune).

### `dev/port-check.sh`
Drop-in. Checks port listeners with `ss` (Linux) or `lsof` (macOS). Supports `--kill` with confirmation.

### `dev/db-reset.sh`
Template. Drops/creates database, runs migrations/seeds. Supports PostgreSQL and MySQL via `DB_ENGINE`. Uses `[db-reset]` prefix.

### `dev/sync-env.sh`
Template. Finds `.env.example` files and copies to `.env` if missing. Supports `--force` and `--diff`.

## Template vs Drop-in

| Directory | Templates | Drop-ins |
|-----------|-----------|----------|
| `dev/` | api-load-test, db-reset, docker-logs, health-check-localdev, health-check-remote, start-dev, sync-env | docker-cleanup, gpu-check, port-check |
| `maintenance/` | — | git-cleanup, lint-all, make-scripts-executable, remove-zone-identifier, scan-secrets |
| `tools/` | — | install-bats-core, install-ollama, uninstall-ollama, install-starship, uninstall-starship |
| `codegen/` | — | generate-code-map |
