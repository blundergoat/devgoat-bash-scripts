#!/usr/bin/env bash
set -euo pipefail

# =============================================================================
# Docker Logs - Tail and color-code Docker Compose service logs
# =============================================================================
# Usage:
#   ./scripts/docker-logs.sh                    # Follow all services
#   ./scripts/docker-logs.sh api                # Follow specific service
#   ./scripts/docker-logs.sh --lines 100        # Show last 100 lines
#   ./scripts/docker-logs.sh --filter error     # Filter for errors
# =============================================================================

# ---- CONFIGURATION ----
# Customize these variables for your project, or set them as environment variables.
PROJECT_NAME="${PROJECT_NAME:-my-project}"
COMPOSE_FILE="${COMPOSE_FILE:-docker-compose.yml}"
# Space-separated container name patterns to follow (empty = all)
CONTAINER_PATTERNS="${CONTAINER_PATTERNS:-}"
# ---- END CONFIGURATION ----

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
GRAY='\033[0;90m'
BOLD='\033[1m'
NC='\033[0m'

show_help() {
    echo ""
    echo -e "${BOLD}Docker Logs Viewer${NC}"
    echo ""
    echo "Usage:"
    echo "  $0 [SERVICE]          Follow logs (optionally for a specific service)"
    echo "  $0 --follow           Explicitly follow all logs (default)"
    echo "  $0 --lines N          Show last N lines (default: 100)"
    echo "  $0 --filter PATTERN   Filter log output for a pattern"
    echo "  $0 --services         List available services"
    echo "  $0 --help             Show this help"
    echo ""
}

# Defaults
FOLLOW=true
LINES=100
FILTER_PATTERN=""
SERVICE=""
LIST_SERVICES=false

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -h|--help)
            show_help
            exit 0
            ;;
        -f|--follow)
            FOLLOW=true
            shift
            ;;
        --no-follow)
            FOLLOW=false
            shift
            ;;
        -n|--lines)
            LINES="${2:-100}"
            shift 2
            ;;
        --filter)
            FILTER_PATTERN="${2:-}"
            shift 2
            ;;
        --services)
            LIST_SERVICES=true
            shift
            ;;
        -*)
            echo -e "${RED}Unknown option: $1${NC}"
            show_help
            exit 1
            ;;
        *)
            SERVICE="$1"
            shift
            ;;
    esac
done

cd "$PROJECT_ROOT" || exit 1

# Check Docker
if ! command -v docker &>/dev/null; then
    echo -e "${RED}Docker not found${NC}"
    exit 1
fi

COMPOSE_PATH="$PROJECT_ROOT/$COMPOSE_FILE"
if [[ ! -f "$COMPOSE_PATH" ]]; then
    echo -e "${RED}Compose file not found: $COMPOSE_FILE${NC}"
    exit 1
fi

COMPOSE_ARGS=(-f "$COMPOSE_PATH")

# List services
if [[ "$LIST_SERVICES" == true ]]; then
    echo -e "${BOLD}Available services:${NC}"
    docker compose "${COMPOSE_ARGS[@]}" config --services 2>/dev/null | while IFS= read -r svc; do
        echo -e "  ${CYAN}${svc}${NC}"
    done
    exit 0
fi

# Build log command
LOG_ARGS=("${COMPOSE_ARGS[@]}" "logs" "--tail" "$LINES")

if [[ "$FOLLOW" == true ]]; then
    LOG_ARGS+=("--follow")
fi

# Add specific service or container patterns
if [[ -n "$SERVICE" ]]; then
    LOG_ARGS+=("$SERVICE")
elif [[ -n "$CONTAINER_PATTERNS" ]]; then
    for pattern in $CONTAINER_PATTERNS; do
        LOG_ARGS+=("$pattern")
    done
fi

echo -e "${BOLD}Following Docker Compose logs... (Ctrl+C to stop)${NC}"
echo -e "${GRAY}Compose file: $COMPOSE_FILE${NC}"
echo ""

# Color-code output by log level
colorize_logs() {
    while IFS= read -r line; do
        if echo "$line" | grep -qiE "(error|fatal|panic|exception)"; then
            echo -e "${RED}${line}${NC}"
        elif echo "$line" | grep -qiE "(warn)"; then
            echo -e "${YELLOW}${line}${NC}"
        elif echo "$line" | grep -qiE "(debug|trace)"; then
            echo -e "${GRAY}${line}${NC}"
        elif echo "$line" | grep -qiE "(info|ready|started|listening)"; then
            echo -e "${GREEN}${line}${NC}"
        else
            echo "$line"
        fi
    done
}

if [[ -n "$FILTER_PATTERN" ]]; then
    docker compose "${LOG_ARGS[@]}" 2>&1 | grep --line-buffered -iE "$FILTER_PATTERN" | colorize_logs
else
    docker compose "${LOG_ARGS[@]}" 2>&1 | colorize_logs
fi
