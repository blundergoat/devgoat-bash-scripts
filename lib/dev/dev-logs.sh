#!/usr/bin/env bash
set -euo pipefail

# =============================================================================
# Development Logs Viewer
# =============================================================================
# Tails and formats development logs for easier debugging.
#
# Usage:
#   ./scripts/dev-logs.sh           # Follow all logs
#   ./scripts/dev-logs.sh api       # Follow API logs only
#   ./scripts/dev-logs.sh web       # Follow frontend logs only
#   ./scripts/dev-logs.sh --errors  # Show only errors/warnings
#   ./scripts/dev-logs.sh --summary # Show log summary
# =============================================================================

# ---- CONFIGURATION ----
# Customize these variables for your project, or set them as environment variables.
PROJECT_NAME="${PROJECT_NAME:-my-project}"
LOGS_SUBDIR="${LOGS_SUBDIR:-logs}"
API_LOG_FILE="${API_LOG_FILE:-api.log}"
WEB_LOG_FILE="${WEB_LOG_FILE:-web.log}"
API_LABEL="${API_LABEL:-API}"
WEB_LABEL="${WEB_LABEL:-WEB}"
START_COMMAND="${START_COMMAND:-./scripts/start-dev.sh}"
# ---- END CONFIGURATION ----

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
LOGS_DIR="$PROJECT_ROOT/$LOGS_SUBDIR"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
MAGENTA='\033[0;35m'
CYAN='\033[0;36m'
GRAY='\033[0;90m'
WHITE='\033[0;97m'
BOLD='\033[1m'
NC='\033[0m' # No Color

# Ensure logs directory exists
mkdir -p "$LOGS_DIR"

show_help() {
    echo ""
    echo -e "${BOLD}Development Logs Viewer${NC}"
    echo ""
    echo "Usage:"
    echo "  $0              Follow all logs (${API_LABEL} + ${WEB_LABEL})"
    echo "  $0 api          Follow ${API_LABEL} logs only (${LOGS_SUBDIR}/${API_LOG_FILE})"
    echo "  $0 web          Follow ${WEB_LABEL} logs only (${LOGS_SUBDIR}/${WEB_LOG_FILE})"
    echo "  $0 --errors     Show only errors and warnings"
    echo "  $0 --last N     Show last N lines (default: 50)"
    echo "  $0 --summary    Show log file summary"
    echo "  $0 --clear      Clear all log files"
    echo ""
}

# Format API log line with colors (for text logs)
format_api_log() {
    while IFS= read -r line; do
        # Color ERROR lines red
        if echo "$line" | grep -qE "(ERROR|error|Error)"; then
            echo -e "${RED}${line}${NC}"
        # Color WARN lines yellow
        elif echo "$line" | grep -qE "(WARN|warn|Warn)"; then
            echo -e "${YELLOW}${line}${NC}"
        # Color DEBUG lines gray
        elif echo "$line" | grep -qE "(DEBUG|debug|Debug)"; then
            echo -e "${GRAY}${line}${NC}"
        # Color status codes
        elif echo "$line" | grep -qE "status=[45][0-9]{2}"; then
            echo -e "${RED}${line}${NC}"
        elif echo "$line" | grep -qE "status=[23][0-9]{2}"; then
            echo -e "${GREEN}${line}${NC}"
        else
            echo "$line"
        fi
    done
}

# Format frontend log line
format_frontend_log() {
    while IFS= read -r line; do
        # Prefix with label and color
        if echo "$line" | grep -qiE "(error|fail|exception)"; then
            echo -e "${MAGENTA}[${WEB_LABEL}]${NC} ${RED}${line}${NC}"
        elif echo "$line" | grep -qiE "(warn)"; then
            echo -e "${MAGENTA}[${WEB_LABEL}]${NC} ${YELLOW}${line}${NC}"
        else
            echo -e "${MAGENTA}[${WEB_LABEL}]${NC} ${line}"
        fi
    done
}

# Tail API logs
tail_api() {
    local follow="${1:-true}"
    local api_log="$LOGS_DIR/$API_LOG_FILE"

    if [ ! -f "$api_log" ]; then
        echo -e "${YELLOW}No ${API_LABEL} log found at $api_log${NC}"
        echo -e "${GRAY}Start the service with: ${START_COMMAND}${NC}"
        return 1
    fi

    echo -e "${CYAN}=== ${API_LABEL} Logs ($api_log) ===${NC}"

    if [ "$follow" = "true" ]; then
        tail -f "$api_log" | format_api_log
    else
        tail -n "${LINES:-50}" "$api_log" | format_api_log
    fi
}

# Tail frontend logs
tail_frontend() {
    local follow="${1:-true}"
    local web_log="$LOGS_DIR/$WEB_LOG_FILE"

    if [ ! -f "$web_log" ]; then
        echo -e "${YELLOW}No ${WEB_LABEL} log found at $web_log${NC}"
        echo -e "${GRAY}Start the service with: ${START_COMMAND}${NC}"
        return 1
    fi

    echo -e "${MAGENTA}=== ${WEB_LABEL} Logs ($web_log) ===${NC}"

    if [ "$follow" = "true" ]; then
        tail -f "$web_log" | format_frontend_log
    else
        tail -n "${LINES:-50}" "$web_log" | format_frontend_log
    fi
}

# Tail all logs (interleaved)
tail_all() {
    local api_log="$LOGS_DIR/$API_LOG_FILE"
    local web_log="$LOGS_DIR/$WEB_LOG_FILE"

    echo -e "${BOLD}Following all logs... (Ctrl+C to stop)${NC}"
    echo ""

    # Create empty logs if they don't exist
    touch "$api_log"
    touch "$web_log" 2>/dev/null || true

    # Use tail with multiple files
    tail -f "$api_log" 2>/dev/null | while IFS= read -r line; do
        echo -e "${CYAN}[${API_LABEL}]${NC} $line"
    done &
    API_TAIL_PID=$!

    if [ -f "$web_log" ]; then
        tail -f "$web_log" 2>/dev/null | while IFS= read -r line; do
            echo -e "${MAGENTA}[${WEB_LABEL}]${NC} $line"
        done &
        WEB_TAIL_PID=$!
    fi

    # Cleanup on exit
    trap "kill $API_TAIL_PID 2>/dev/null; kill ${WEB_TAIL_PID:-0} 2>/dev/null; exit 0" SIGINT SIGTERM

    wait
}

# Show only errors
show_errors() {
    local api_log="$LOGS_DIR/$API_LOG_FILE"

    echo -e "${BOLD}Showing errors and warnings...${NC}"
    echo ""

    if [ -f "$api_log" ]; then
        echo -e "${CYAN}=== ${API_LABEL} Errors ===${NC}"
        grep -iE "(error|warn|fail|panic)" "$api_log" 2>/dev/null | tail -50 | format_api_log || echo -e "${GREEN}No errors found${NC}"
    fi
}

# Clear logs
clear_logs() {
    echo -e "${YELLOW}Clearing logs...${NC}"
    rm -f "$LOGS_DIR"/*.log
    echo -e "${GREEN}Logs cleared${NC}"
}

# Show summary
show_summary() {
    echo ""
    echo -e "${BOLD}Log Summary${NC}"
    echo -e "${GRAY}─────────────────────────────────────${NC}"

    for log in "$LOGS_DIR"/*.log; do
        if [ -f "$log" ]; then
            local name=$(basename "$log")
            local lines=$(wc -l < "$log" 2>/dev/null || echo 0)
            local errors=$(grep -ciE "error" "$log" 2>/dev/null || echo 0)
            local warns=$(grep -ciE "warn" "$log" 2>/dev/null || echo 0)
            local size=$(du -h "$log" 2>/dev/null | cut -f1 || echo "0")

            echo -e "  ${CYAN}$name${NC}: $lines lines, ${size}"
            if [ "$errors" -gt 0 ]; then
                echo -e "    ${RED}x $errors errors${NC}"
            fi
            if [ "$warns" -gt 0 ]; then
                echo -e "    ${YELLOW}! $warns warnings${NC}"
            fi
        fi
    done
    echo ""
}

# Main
main() {
    case "${1:-}" in
        api)
            tail_api true
            ;;
        frontend|web)
            tail_frontend true
            ;;
        --errors|-e)
            show_errors
            ;;
        --last|-n)
            LINES="${2:-50}"
            tail_api false
            ;;
        --clear|-c)
            clear_logs
            ;;
        --summary|-s)
            show_summary
            ;;
        --help|-h)
            show_help
            ;;
        "")
            tail_all
            ;;
        *)
            echo -e "${RED}Unknown option: $1${NC}"
            show_help
            exit 1
            ;;
    esac
}

main "$@"
