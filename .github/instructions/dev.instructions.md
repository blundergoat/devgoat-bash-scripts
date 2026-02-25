---
applyTo: "lib/dev/**,lib/maintenance/**,lib/setup/**,lib/codegen/**"
---

# dev / maintenance / setup / codegen Domains

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

## Template vs Drop-in

| Directory | Templates | Drop-ins |
|-----------|-----------|----------|
| `dev/` | api-load-test, dev-logs, health-check-localdev, health-check-remote, start-dev | gpu-check |
| `maintenance/` | — | make-scripts-executable, remove-zone-identifier |
| `setup/` | — | install-ollama, uninstall-ollama |
| `codegen/` | generate-api-client | generate-code-map |
