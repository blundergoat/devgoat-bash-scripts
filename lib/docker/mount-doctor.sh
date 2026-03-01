#!/usr/bin/env bash
set -euo pipefail

show_help() {
    cat << HELP
Usage: $(basename "$0") [OPTIONS]

Print container mount diagnostics for docker compose projects.

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

if ! command -v docker >/dev/null 2>&1; then
    echo "docker not found" >&2
    exit 1
fi

echo "Docker info:" 
docker info --format 'Server={{.ServerVersion}} RootDir={{.DockerRootDir}}' || true

echo "Running containers and mounts:"
docker ps --format '{{.Names}}' | while IFS= read -r c; do
    echo "- $c"
    docker inspect "$c" --format '{{range .Mounts}}    {{.Source}} -> {{.Destination}} ({{.Type}}){{println}}{{end}}' || true
done
