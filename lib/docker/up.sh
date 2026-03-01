#!/usr/bin/env bash
set -euo pipefail

# ---- CONFIGURATION ----
COMPOSE_FILE="${COMPOSE_FILE:-docker-compose.yml}"
# ---- END CONFIGURATION ----

show_help() {
    cat << HELP
Usage: $(basename "$0") [OPTIONS]

Start docker compose services in detached mode.

OPTIONS:
    -h, --help      Show this help message
HELP
}

if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
    show_help
    exit 0
fi

if [[ $# -gt 0 ]]; then
    echo "Unknown option: $1" >&2
    show_help
    exit 1
fi

exec docker compose -f "$COMPOSE_FILE" up -d
