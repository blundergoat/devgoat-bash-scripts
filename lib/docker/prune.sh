#!/usr/bin/env bash
# =============================================================================
# Docker Cleanup - Prune unused Docker resources
# =============================================================================
#
# Removes stopped containers, dangling images, unused volumes, and unused
# networks individually. Shows space reclaimed per step.
#
# Usage:
#   ./scripts/docker-cleanup.sh                # Prune unused resources
#   ./scripts/docker-cleanup.sh --all          # Also remove used images
#   ./scripts/docker-cleanup.sh --dry-run      # Preview what would be removed
#
# =============================================================================

set -euo pipefail

# --- Colours and icons ---
RED='\033[0;31m'
GREEN='\033[0;32m'
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
Usage: $0 [OPTIONS]

Prunes unused Docker resources: containers, images, volumes, and networks.
Shows space reclaimed per category.

OPTIONS:
    -h, --help      Show this help message
    -n, --dry-run   Show what would be removed without removing
    --all           Also remove images in use (docker image prune -a)

EXAMPLES:
    $0                  # Remove unused resources
    $0 --dry-run        # Preview cleanup
    $0 --all            # Aggressive cleanup including used images
EOF
}

# Default values
DRY_RUN=false
PRUNE_ALL=false

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -h|--help)
            show_help
            exit 0
            ;;
        -n|--dry-run)
            DRY_RUN=true
            shift
            ;;
        --all)
            PRUNE_ALL=true
            shift
            ;;
        -*)
            echo -e "${RED}Unknown option: $1${RESET}"
            show_help
            exit 1
            ;;
        *)
            echo -e "${RED}Unexpected argument: $1${RESET}"
            show_help
            exit 1
            ;;
    esac
done

# Check Docker is available
if ! command -v docker &>/dev/null; then
    echo -e "  ${FAIL} Docker not found"
    echo ""
    echo "  Install Docker: https://docs.docker.com/get-docker/"
    exit 1
fi

if ! docker info &>/dev/null 2>&1; then
    echo -e "  ${FAIL} Docker daemon not running"
    exit 1
fi

echo ""
echo -e "${BOLD}Docker Cleanup${RESET}"
echo -e "${DIM}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
echo ""

# --- 1. Containers ---
echo -e "  ${ARROW} Stopped containers..."

stopped_count=$(docker ps -aq --filter status=exited 2>/dev/null | wc -l)
stopped_count="${stopped_count//[^0-9]/}"

if [[ "${stopped_count:-0}" -eq 0 ]]; then
    echo -e "  ${PASS} None to remove"
else
    if [[ "$DRY_RUN" == true ]]; then
        echo -e "  ${YELLOW}Would remove ${stopped_count} container(s)${RESET}"
        docker ps -a --filter status=exited --format "    {{.Names}} ({{.Image}}, {{.Status}})" 2>/dev/null
    else
        prune_output=$(docker container prune -f 2>&1)
        reclaimed=$(echo "$prune_output" | sed -n 's/.*reclaimed approximately \([0-9.]*[A-Za-z]*\).*/\1/p' || echo "0B")
        echo -e "  ${PASS} Removed ${stopped_count} container(s) ${DIM}(${reclaimed})${RESET}"
    fi
fi

echo ""

# --- 2. Images ---
echo -e "  ${ARROW} Unused images..."

if [[ "$PRUNE_ALL" == true ]]; then
    image_args=("-a")
    dangling_count=$(docker images -q 2>/dev/null | wc -l)
else
    image_args=()
    dangling_count=$(docker images -f dangling=true -q 2>/dev/null | wc -l)
fi
dangling_count="${dangling_count//[^0-9]/}"

if [[ "${dangling_count:-0}" -eq 0 ]]; then
    echo -e "  ${PASS} None to remove"
else
    if [[ "$DRY_RUN" == true ]]; then
        echo -e "  ${YELLOW}Would remove ${dangling_count} image(s)${RESET}"
        if [[ "$PRUNE_ALL" == true ]]; then
            docker images --format "    {{.Repository}}:{{.Tag}} ({{.Size}})" 2>/dev/null | head -10
        else
            docker images -f dangling=true --format "    {{.ID}} ({{.Size}})" 2>/dev/null | head -10
        fi
    else
        prune_output=$(docker image prune "${image_args[@]}" -f 2>&1)
        reclaimed=$(echo "$prune_output" | sed -n 's/.*reclaimed approximately \([0-9.]*[A-Za-z]*\).*/\1/p' || echo "0B")
        echo -e "  ${PASS} Cleaned images ${DIM}(${reclaimed})${RESET}"
    fi
fi

echo ""

# --- 3. Volumes ---
echo -e "  ${ARROW} Unused volumes..."

volume_count=$(docker volume ls -qf dangling=true 2>/dev/null | wc -l)
volume_count="${volume_count//[^0-9]/}"

if [[ "${volume_count:-0}" -eq 0 ]]; then
    echo -e "  ${PASS} None to remove"
else
    if [[ "$DRY_RUN" == true ]]; then
        echo -e "  ${YELLOW}Would remove ${volume_count} volume(s)${RESET}"
        docker volume ls -f dangling=true --format "    {{.Name}}" 2>/dev/null | head -10
    else
        prune_output=$(docker volume prune -f 2>&1)
        reclaimed=$(echo "$prune_output" | sed -n 's/.*reclaimed approximately \([0-9.]*[A-Za-z]*\).*/\1/p' || echo "0B")
        echo -e "  ${PASS} Removed ${volume_count} volume(s) ${DIM}(${reclaimed})${RESET}"
    fi
fi

echo ""

# --- 4. Networks ---
echo -e "  ${ARROW} Unused networks..."

# Count non-default networks
network_count=$(docker network ls -q --filter type=custom 2>/dev/null | wc -l)
network_count="${network_count//[^0-9]/}"

if [[ "${network_count:-0}" -eq 0 ]]; then
    echo -e "  ${PASS} None to remove"
else
    if [[ "$DRY_RUN" == true ]]; then
        echo -e "  ${YELLOW}Would prune unused custom networks${RESET}"
        docker network ls --filter type=custom --format "    {{.Name}}" 2>/dev/null | head -10
    else
        prune_output=$(docker network prune -f 2>&1)
        echo -e "  ${PASS} Pruned unused networks"
    fi
fi

# --- Summary ---
echo ""
echo -e "${DIM}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
echo ""

if [[ "$DRY_RUN" == true ]]; then
    echo -e "  ${YELLOW}${BOLD}DRY RUN${RESET} - no resources were removed"
else
    # Show total disk usage after cleanup
    disk_usage=$(docker system df --format "{{.Size}}" 2>/dev/null | head -1 || echo "unknown")
    echo -e "  ${PASS} ${GREEN}${BOLD}Cleanup complete.${RESET} ${DIM}Total Docker disk usage: ${disk_usage}${RESET}"
fi
echo ""
