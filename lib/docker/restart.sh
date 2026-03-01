#!/usr/bin/env bash
set -euo pipefail

# ---- CONFIGURATION ----
COMPOSE_FILE="${COMPOSE_FILE:-docker-compose.yml}"
# ---- END CONFIGURATION ----

show_help() {
    cat << HELP
Usage: $(basename "$0") [OPTIONS]

Restart docker compose services using down + up -d.

OPTIONS:
    -h, --help      Show this help message
HELP
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        -h|--help)
            show_help
            exit 0
            ;;
        *)
            echo "Unknown option: $1" >&2
            show_help
            exit 1
            ;;
    esac
done

if ! command -v docker >/dev/null 2>&1; then
    echo "docker not found" >&2
    exit 1
fi

docker compose -f "$COMPOSE_FILE" down
docker compose -f "$COMPOSE_FILE" up -d
