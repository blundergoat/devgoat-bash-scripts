#!/usr/bin/env bash
set -euo pipefail

# ---- CONFIGURATION ----
API_URL="${API_URL:-http://localhost:8000}"
AUTH_TOKEN="${AUTH_TOKEN:-}"
# ---- END CONFIGURATION ----

show_help() {
    cat << HELP
Usage: $(basename "$0") [OPTIONS]

Basic API auth probe using bearer token against /health.

OPTIONS:
    -h, --help          Show this help message
    --url <url>         API base URL (default from API_URL)
    --token <token>     Bearer token (default from AUTH_TOKEN)
HELP
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        -h|--help)
            show_help
            exit 0
            ;;
        --url)
            API_URL="${2:-}"
            shift 2
            ;;
        --token)
            AUTH_TOKEN="${2:-}"
            shift 2
            ;;
        *)
            echo "Unknown option: $1" >&2
            show_help
            exit 1
            ;;
    esac
done

if [[ -z "$AUTH_TOKEN" ]]; then
    echo "AUTH_TOKEN is required" >&2
    exit 1
fi

code="$(curl -s -o /dev/null -w '%{http_code}' -H "Authorization: Bearer ${AUTH_TOKEN}" "${API_URL}/health" || true)"
if [[ "$code" == "200" ]]; then
    echo "Auth probe passed (${code})"
    exit 0
fi

echo "Auth probe failed (${code})" >&2
exit 1
