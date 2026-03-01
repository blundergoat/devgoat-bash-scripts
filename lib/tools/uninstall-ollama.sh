#!/usr/bin/env bash
# =============================================================================
# Uninstall Ollama - Removes Ollama binary, models, service, and user/group
# =============================================================================
# Usage: ./uninstall-ollama.sh [-y|--yes] [-h|--help]
#
# Stops the Ollama service, removes the binary, models, and systemd unit.
# Run this script in WSL or any Unix-like terminal.
#
# Options:
#   -y, --yes     Skip confirmation prompts (auto-remove everything)
#   -h, --help    Show this help message
# =============================================================================

set -euo pipefail

# ── Colors ──────────────────────────────────────────────────────────
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

# ── Helpers ─────────────────────────────────────────────────────────
command_exists() {
    command -v "$1" &>/dev/null
}

confirm_or_auto() {
    local msg="${1:-Continue?}"
    if [[ "${AUTO_YES}" == "true" ]]; then
        return 0
    fi
    if [[ -t 0 ]]; then
        read -r -p "${msg} (y/n): " _confirm
        if [[ "$_confirm" != "y" ]]; then
            return 1
        fi
    fi
    return 0
}

remove_dir_prompt() {
    local dir="$1"
    if [[ ! -d "$dir" ]]; then
        echo -e "${YELLOW}Not found: ${dir}${NC}"
        return 0
    fi
    if ! confirm_or_auto "Remove ${dir}?"; then
        echo -e "${YELLOW}Skipped: ${dir}${NC}"
        return 0
    fi
    if rm -rf "$dir"; then
        echo -e "${GREEN}Removed: ${dir}${NC}"
    else
        echo -e "${RED}Failed to remove: ${dir}${NC}"
    fi
    return 0
}

print_platform() {
    local platform="Unknown"
    if [[ "$OSTYPE" == "darwin"* ]]; then
        platform="macOS"
    elif [[ "$OSTYPE" == "linux-gnu"* ]]; then
        platform="Linux"
        if [[ -f /proc/version ]] && grep -qi microsoft /proc/version 2>/dev/null; then
            platform="Linux (WSL)"
        fi
    fi
    echo -e "\n${CYAN}Detected platform: ${BOLD}${platform}${NC}"
}

show_help() {
    echo ""
    echo -e "${CYAN}Uninstall Ollama${NC}"
    echo ""
    echo "Usage: $0 [options]"
    echo ""
    echo "Stops the Ollama service, removes the binary, models, and systemd unit."
    echo ""
    echo "Options:"
    echo "  -y, --yes     Skip confirmation prompts"
    echo "  -h, --help    Show this help message"
    echo ""
}

# ── Parse arguments ─────────────────────────────────────────────────
AUTO_YES="false"

while [[ $# -gt 0 ]]; do
    case $1 in
        -h|--help) show_help; exit 0 ;;
        -y|--yes) AUTO_YES="true"; shift ;;
        *) echo -e "${RED}Unknown option: $1${NC}"; show_help; exit 1 ;;
    esac
done

# ── Block Git Bash ──────────────────────────────────────────────────
if [[ "$OSTYPE" == "msys" ]] || [[ "$OSTYPE" == "mingw"* ]] || [[ "$OSTYPE" == "cygwin"* ]]; then
    echo -e "${RED}Ollama uninstaller is not supported in Git Bash/MSYS/Cygwin.${NC}"
    echo -e "${YELLOW}Use WSL (Ubuntu/etc) and run this script inside WSL.${NC}"
    exit 1
fi

# ── Main ────────────────────────────────────────────────────────────
echo -e "${CYAN}Starting Ollama uninstallation process...${NC}"
print_platform

OLLAMA_BIN="/usr/local/bin/ollama"
OLLAMA_MODELS="$HOME/.ollama"
OLLAMA_SERVICE="ollama.service"

if command_exists ollama; then
    CURRENT_VERSION=$(ollama --version 2>/dev/null | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' || echo "unknown")
    echo -e "${YELLOW}Found Ollama v${CURRENT_VERSION} at: $(command -v ollama)${NC}"
else
    echo -e "${YELLOW}'ollama' command not found in PATH.${NC}"
fi

# ── Stop running Ollama processes ────────────────────────────────

echo -e "\n${CYAN}========================================"
echo -e "Stopping Ollama"
echo -e "========================================${NC}"

# Stop systemd service if it exists
if systemctl is-active --quiet "$OLLAMA_SERVICE" 2>/dev/null; then
    echo -e "${YELLOW}Stopping Ollama systemd service...${NC}"
    sudo systemctl stop "$OLLAMA_SERVICE" 2>/dev/null || true
    sudo systemctl disable "$OLLAMA_SERVICE" 2>/dev/null || true
    echo -e "${GREEN}Service stopped and disabled.${NC}"
else
    echo -e "${YELLOW}No active systemd service found.${NC}"
fi

# Kill any remaining ollama processes
if pgrep -x ollama >/dev/null 2>&1; then
    echo -e "${YELLOW}Killing remaining Ollama processes...${NC}"
    pkill -x ollama 2>/dev/null || true
    sleep 1
    if pgrep -x ollama >/dev/null 2>&1; then
        pkill -9 -x ollama 2>/dev/null || true
    fi
    echo -e "${GREEN}Ollama processes terminated.${NC}"
else
    echo -e "${YELLOW}No running Ollama processes found.${NC}"
fi

# ── Remove binary ────────────────────────────────────────────────

echo -e "\n${CYAN}========================================"
echo -e "Removing Ollama binary"
echo -e "========================================${NC}"

if [[ -f "$OLLAMA_BIN" ]]; then
    sudo rm -f "$OLLAMA_BIN"
    echo -e "${GREEN}Removed ${OLLAMA_BIN}${NC}"
else
    echo -e "${YELLOW}Binary not found at ${OLLAMA_BIN}${NC}"
    if command_exists ollama; then
        ACTUAL_PATH=$(command -v ollama)
        echo -e "${YELLOW}Found ollama at ${ACTUAL_PATH} — remove it manually if needed.${NC}"
    fi
fi

# ── Remove systemd unit file ────────────────────────────────────

echo -e "\n${CYAN}========================================"
echo -e "Removing systemd service"
echo -e "========================================${NC}"

SYSTEMD_UNIT="/etc/systemd/system/${OLLAMA_SERVICE}"
if [[ -f "$SYSTEMD_UNIT" ]]; then
    sudo rm -f "$SYSTEMD_UNIT"
    sudo systemctl daemon-reload 2>/dev/null || true
    echo -e "${GREEN}Removed ${SYSTEMD_UNIT}${NC}"
else
    echo -e "${YELLOW}No systemd unit file found at ${SYSTEMD_UNIT}${NC}"
fi

# ── Remove ollama user/group (if created by installer) ───────────

echo -e "\n${CYAN}========================================"
echo -e "Removing Ollama user and group"
echo -e "========================================${NC}"

if id ollama >/dev/null 2>&1; then
    sudo userdel ollama 2>/dev/null || true
    echo -e "${GREEN}Removed 'ollama' user.${NC}"
else
    echo -e "${YELLOW}No 'ollama' user found.${NC}"
fi

if getent group ollama >/dev/null 2>&1; then
    sudo groupdel ollama 2>/dev/null || true
    echo -e "${GREEN}Removed 'ollama' group.${NC}"
else
    echo -e "${YELLOW}No 'ollama' group found.${NC}"
fi

# ── Clean up models and data ─────────────────────────────────────

echo -e "\n${CYAN}========================================"
echo -e "Cleaning up Ollama data"
echo -e "========================================${NC}"

remove_dir_prompt "$OLLAMA_MODELS"

# Also check the system-level data dir used by the service
OLLAMA_SYSTEM_DATA="/usr/share/ollama/.ollama"
if [[ -d "$OLLAMA_SYSTEM_DATA" ]]; then
    echo -e "${YELLOW}Found system-level Ollama data at ${OLLAMA_SYSTEM_DATA}${NC}"
    if confirm_or_auto "Remove ${OLLAMA_SYSTEM_DATA}?"; then
        sudo rm -rf "$OLLAMA_SYSTEM_DATA"
        echo -e "${GREEN}Removed ${OLLAMA_SYSTEM_DATA}${NC}"
    else
        echo -e "${YELLOW}Kept ${OLLAMA_SYSTEM_DATA}${NC}"
    fi
fi

# ── Verify ───────────────────────────────────────────────────────

echo -e "\n${CYAN}========================================"
echo -e "Verifying uninstall"
echo -e "========================================${NC}"

if command_exists ollama; then
    OLLAMA_PATH=$(command -v ollama)
    echo -e "${YELLOW}ollama command still present at: ${OLLAMA_PATH}${NC}"
    echo -e "${YELLOW}You may need to restart your shell or remove it manually.${NC}"
else
    echo -e "${GREEN}Ollama command not found. Uninstall appears complete.${NC}"
fi

echo -e "\n${GREEN}========================================"
echo -e "Uninstallation process completed!"
echo -e "========================================${NC}"
