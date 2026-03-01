#!/usr/bin/env bash
set -euo pipefail

show_help() {
    cat << HELP
Usage: $(basename "$0") [OPTIONS]

Diagnose docker network state and optionally prune unused networks.

OPTIONS:
    -h, --help      Show this help message
    --prune         Prune unused docker networks
HELP
}

PRUNE=false
while [[ $# -gt 0 ]]; do
    case "$1" in
        -h|--help) show_help; exit 0 ;;
        --prune) PRUNE=true; shift ;;
        *) echo "Unknown option: $1" >&2; show_help; exit 1 ;;
    esac
done

if ! command -v docker >/dev/null 2>&1; then
    echo "docker not found" >&2
    exit 1
fi

echo "Docker network summary:"
docker network ls

if [[ "$PRUNE" == true ]]; then
    docker network prune -f
fi
