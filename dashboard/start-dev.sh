#!/usr/bin/env bash
# =============================================================================
# Dashboard Launcher - Start the PHP script-runner web UI
# =============================================================================
#
# Starts a PHP built-in server serving the dashboard on localhost.
# The dashboard provides a browser UI for running project scripts.
#
# Usage:
#   ./dashboard/start-dev.sh              # Start on default port
#   ./dashboard/start-dev.sh --port 9000  # Start on custom port
#   ./dashboard/start-dev.sh -h|--help    # Show help
#
# Prerequisites:
#   - PHP 8.1+ with posix extension
#   - script(1) command (standard on Linux/macOS)
#   - config.php in the dashboard directory (copy from config.example.php)
#
# =============================================================================

set -euo pipefail

# ---- CONFIGURATION ----
# Port for the PHP built-in server (localhost only).
DASHBOARD_PORT="${DASHBOARD_PORT:-8899}"

# Path to the project scripts directory (relative to the project root).
# The dashboard runs scripts from this directory. Defaults to the project
# root (parent of the dashboard/ directory).
SCRIPTS_DIR="${SCRIPTS_DIR:-.}"

# Project name shown in the dashboard title and branding.
PROJECT_NAME="${PROJECT_NAME:-DevGoat DevEx Dashboard}"

# Optional site URL shown as a link in the dashboard header.
# Leave empty to hide the link. Example: https://dev.example.com
SITE_URL="${SITE_URL:-}"

# Environment name shown in the dashboard header.
# Auto-detected from the project path if not set.
ENV_NAME="${ENV_NAME:-}"
# ---- END CONFIGURATION ----

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
BOLD='\033[1m'
NC='\033[0m'

TAG="[dashboard]"

log()     { echo -e "${BLUE}${TAG}${NC} $*"; }
success() { echo -e "${GREEN}${TAG}${NC} $*"; }
warn()    { echo -e "${YELLOW}${TAG}${NC} $*"; }
error()   { echo -e "${RED}${TAG}${NC} $*"; exit 1; }

show_help() {
    cat << EOF
Usage: $0 [OPTIONS]

Start the PHP dashboard web UI for running project scripts from the browser.
Binds to 127.0.0.1 only - never exposed to the network.

OPTIONS:
    -h, --help          Show this help message
    -p, --port PORT     Override the dashboard port (default: ${DASHBOARD_PORT})

CONFIGURATION:
    DASHBOARD_PORT      Server port (default: 8899)
    SCRIPTS_DIR         Scripts directory relative to project root (default: .)
    PROJECT_NAME        Project name for dashboard branding (default: my-project)
    SITE_URL            Optional site URL shown in header (default: empty)
    ENV_NAME            Environment name shown in header (default: auto-detected)

EXAMPLES:
    $0                          # Start on port 8899
    $0 --port 9000              # Start on port 9000
    PROJECT_NAME=acme $0        # Start with custom project name
EOF
}

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -h|--help)
            show_help
            exit 0
            ;;
        -p|--port)
            [[ -z "${2:-}" ]] && error "Missing value for --port"
            DASHBOARD_PORT="$2"
            shift 2
            ;;
        -*)
            echo -e "${RED}Unknown option: $1${NC}" >&2
            show_help
            exit 1
            ;;
        *)
            echo -e "${RED}Unexpected argument: $1${NC}" >&2
            show_help
            exit 1
            ;;
    esac
done

# ── Preflight checks ─────────────────────────────────────────────

log "Checking prerequisites..."

# PHP
if ! command -v php &>/dev/null; then
    error "PHP not found. Install PHP 8.1+ to use the dashboard."
fi

PHP_VERSION=$(php -r 'echo PHP_MAJOR_VERSION . "." . PHP_MINOR_VERSION;')
PHP_MAJOR=$(php -r 'echo PHP_MAJOR_VERSION;')
PHP_MINOR=$(php -r 'echo PHP_MINOR_VERSION;')
if [[ "${PHP_MAJOR}" -lt 8 ]] || { [[ "${PHP_MAJOR}" -eq 8 ]] && [[ "${PHP_MINOR}" -lt 1 ]]; }; then
    error "PHP 8.1+ required, found ${PHP_VERSION}"
fi
log "PHP ${PHP_VERSION} found"

# script(1) - required for PTY emulation during script execution
if ! command -v script &>/dev/null; then
    error "script command not found - install util-linux"
fi

# config.php - auto-create from example if missing
if [[ ! -f "${SCRIPT_DIR}/config.php" ]]; then
    if [[ -f "${SCRIPT_DIR}/config.example.php" ]]; then
        warn "config.php not found — creating from config.example.php"
        cp "${SCRIPT_DIR}/config.example.php" "${SCRIPT_DIR}/config.php"
        warn "Edit ${SCRIPT_DIR}/config.php to customize your script registry"
    else
        error "Cannot start without config.php (and no config.example.php to copy from)"
    fi
fi

# index.php
if [[ ! -f "${SCRIPT_DIR}/index.php" ]]; then
    error "index.php not found in ${SCRIPT_DIR}/ — PHP dashboard files not yet ported. See TODO_dashboard-plan.md"
fi

# ── Resolve SCRIPTS_DIR to absolute path ────────────────────────
# PHP must receive an absolute path. If SCRIPTS_DIR is relative,
# resolve it from the project root (parent of this dashboard dir).

if [[ "${SCRIPTS_DIR}" != /* ]]; then
    PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
    SCRIPTS_DIR="${PROJECT_ROOT}/${SCRIPTS_DIR}"
fi

if [[ ! -d "${SCRIPTS_DIR}" ]]; then
    error "SCRIPTS_DIR does not exist: ${SCRIPTS_DIR}"
fi

SCRIPTS_DIR="$(cd "${SCRIPTS_DIR}" && pwd)"
log "Scripts dir: ${SCRIPTS_DIR}"

# ── Export env vars for PHP ───────────────────────────────────────

export DASHBOARD_PORT
export SCRIPTS_DIR
export PROJECT_NAME
export SITE_URL
export ENV_NAME

# ── Start server ─────────────────────────────────────────────────

echo ""
success "${BOLD}Starting ${PROJECT_NAME} Dashboard${NC}"
log "URL:  http://localhost:${DASHBOARD_PORT}"
log "Dir:  ${SCRIPT_DIR}"
log ""
log "Press Ctrl+C to stop."
echo ""

# Filter out noisy TCP connection logs from PHP's built-in server,
# keep the startup banner and any custom [dashboard] log lines.
php -S "127.0.0.1:${DASHBOARD_PORT}" "${SCRIPT_DIR}/index.php" 2>&1 \
    | grep --line-buffered -v -E 'Accepted$|Closing$|speculative|without sending'
