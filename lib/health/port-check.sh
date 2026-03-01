#!/usr/bin/env bash
# =============================================================================
# Port Check - Show what's listening on specified ports
# =============================================================================
#
# Checks whether given ports are in use and shows the PID, process name,
# and user for each listener. Supports Linux (ss) and macOS (lsof).
#
# Usage:
#   ./scripts/port-check.sh 3000 8080          # Check specific ports
#   ./scripts/port-check.sh 3000 --kill         # Kill process on port 3000
#   ./scripts/port-check.sh                     # Check common dev ports
#
# =============================================================================

set -euo pipefail

# --- Colours and icons ---
RED='\033[0;31m'
GREEN='\033[0;32m'
# shellcheck disable=SC2034
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
DIM='\033[2m'
BOLD='\033[1m'
RESET='\033[0m'

PASS="${GREEN}✔${RESET}"
FAIL="${RED}✘${RESET}"
ARROW="${BLUE}→${RESET}"

show_help() {
    cat << EOF
Usage: $0 [OPTIONS] [PORT...]

Checks whether specified ports are in use and shows the PID, process name,
and user for each listener.

OPTIONS:
    -h, --help      Show this help message
    --kill          Kill the process listening on the specified port(s)
                    (prompts for confirmation)

ARGUMENTS:
    PORT            One or more port numbers (space or comma separated)

EXAMPLES:
    $0 3000 8080            # Check ports 3000 and 8080
    $0 3306,6379,8080       # Comma-separated list
    $0 3000 --kill          # Kill process on port 3000
    $0                      # Check common dev ports
EOF
}

# Default values
KILL_MODE=false
PORTS=()

# Common development ports (used when no ports specified)
DEFAULT_PORTS=(3000 3306 3706 5432 6379 8000 8080 8081 8082 8086 8087 8899 11434 11436)

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -h|--help)
            show_help
            exit 0
            ;;
        --kill)
            KILL_MODE=true
            shift
            ;;
        -*)
            echo -e "${RED}Unknown option: $1${RESET}"
            show_help
            exit 1
            ;;
        *)
            # Support comma-separated and space-separated ports
            IFS=',' read -ra _parts <<< "$1"
            for _p in "${_parts[@]}"; do
                _p="${_p// /}"
                if [[ "$_p" =~ ^[0-9]+$ ]]; then
                    PORTS+=("$_p")
                elif [[ -n "$_p" ]]; then
                    echo -e "${RED}Invalid port: $_p${RESET}"
                    exit 1
                fi
            done
            shift
            ;;
    esac
done

# Use default ports if none specified
if [[ ${#PORTS[@]} -eq 0 ]]; then
    PORTS=("${DEFAULT_PORTS[@]}")
fi

# Detect platform
IS_MACOS=false
if [[ "$(uname -s)" == "Darwin" ]]; then
    IS_MACOS=true
fi

# Get listener info for a port
# Sets: LISTENER_PID, LISTENER_PROC, LISTENER_USER
get_listener() {
    local port="$1"
    LISTENER_PID=""
    LISTENER_PROC=""
    LISTENER_USER=""

    if [[ "$IS_MACOS" == true ]]; then
        # macOS: use lsof
        local lsof_output
        lsof_output=$(lsof -iTCP:"$port" -sTCP:LISTEN -P -n 2>/dev/null | tail -n +2 | head -1) || true
        if [[ -n "$lsof_output" ]]; then
            LISTENER_PROC=$(echo "$lsof_output" | awk '{print $1}')
            LISTENER_PID=$(echo "$lsof_output" | awk '{print $2}')
            LISTENER_USER=$(echo "$lsof_output" | awk '{print $3}')
        fi
    else
        # Linux: use ss
        local ss_output
        ss_output=$(ss -tlnp "sport = :${port}" 2>/dev/null | tail -n +2 | head -1) || true
        if [[ -n "$ss_output" ]]; then
            LISTENER_PID=$(echo "$ss_output" | grep -oP 'pid=\K[0-9]+' | head -1) || true
            if [[ -n "$LISTENER_PID" ]]; then
                LISTENER_PROC=$(ps -p "$LISTENER_PID" -o comm= 2>/dev/null || echo "unknown")
                LISTENER_USER=$(ps -p "$LISTENER_PID" -o user= 2>/dev/null || echo "unknown")
            fi
        fi
    fi
}

echo ""
echo -e "${BOLD}Port Check${RESET}"
echo -e "${DIM}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
echo ""

found_listeners=0

for port in "${PORTS[@]}"; do
    get_listener "$port"

    if [[ -n "$LISTENER_PID" ]]; then
        found_listeners=$((found_listeners + 1))
        echo -e "  ${PASS} Port ${BOLD}${port}${RESET}  ${DIM}${LISTENER_PROC} (pid ${LISTENER_PID}, user ${LISTENER_USER})${RESET}"

        if [[ "$KILL_MODE" == true ]]; then
            echo ""
            echo -e "  ${ARROW} Kill ${LISTENER_PROC} (pid ${LISTENER_PID}) on port ${port}?"
            read -r -p "     Confirm [y/N]: " confirm
            if [[ "$confirm" =~ ^[Yy]$ ]]; then
                if kill "$LISTENER_PID" 2>/dev/null; then
                    echo -e "  ${PASS} Killed pid ${LISTENER_PID}"
                else
                    echo -e "  ${FAIL} ${RED}Failed to kill pid ${LISTENER_PID} - try sudo${RESET}"
                fi
            else
                echo -e "  ${DIM}Skipped${RESET}"
            fi
            echo ""
        fi
    else
        echo -e "  ${FAIL} Port ${BOLD}${port}${RESET}  ${DIM}no listener${RESET}"
    fi
done

# Summary
echo ""
echo -e "${DIM}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
echo ""
echo -e "  ${found_listeners}/${#PORTS[@]} port(s) in use"
echo ""
