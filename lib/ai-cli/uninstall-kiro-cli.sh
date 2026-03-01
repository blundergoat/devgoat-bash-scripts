#!/usr/bin/env bash
# GOAT System Uninstaller - Kiro CLI
# Removes Kiro CLI binary, config directories, and PATH entries.
# Run this script in WSL or any Unix-like terminal.

set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/_common.sh"

show_help() {
    echo ""
    echo -e "${CYAN}Kiro CLI Uninstaller${NC}"
    echo ""
    echo "Usage: $0 [options]"
    echo ""
    echo "Options:"
    echo "  -h, --help    Show this help message"
    echo ""
}
while [[ $# -gt 0 ]]; do
    case $1 in
        -h|--help) show_help; exit 0 ;;
        *) echo -e "${RED}Unknown option: $1${NC}"; show_help; exit 1 ;;
    esac
done

block_gitbash "Kiro CLI uninstaller"

echo -e "${CYAN}Starting Kiro CLI uninstallation process...${NC}"
print_platform

KIRO_BIN="$HOME/.local/bin/kiro-cli"

if command_exists kiro-cli; then
    echo -e "${YELLOW}Found 'kiro-cli' command at: $(command -v kiro-cli)${NC}"
else
    echo -e "${YELLOW}'kiro-cli' command not found in PATH.${NC}"
fi

# ── Remove binary ────────────────────────────────────────────────

echo -e "\n${CYAN}========================================"
echo -e "Removing Kiro CLI binary"
echo -e "========================================${NC}"

if [[ -f "$KIRO_BIN" ]]; then
    rm -f "$KIRO_BIN"
    echo -e "${GREEN}Removed ${KIRO_BIN}${NC}"
else
    echo -e "${YELLOW}Binary not found at ${KIRO_BIN}${NC}"
    # Check if it's somewhere else
    if command_exists kiro-cli; then
        ACTUAL_PATH=$(command -v kiro-cli)
        echo -e "${YELLOW}Found kiro-cli at ${ACTUAL_PATH} - remove it manually if needed.${NC}"
    fi
fi

# ── Clean up config directories ──────────────────────────────────

echo -e "\n${CYAN}========================================"
echo -e "Cleaning up Kiro CLI data"
echo -e "========================================${NC}"

for dir in "$HOME/.kiro" "$HOME/.config/kiro" "$HOME/.cache/kiro"; do
    remove_dir_prompt "$dir"
done

# ── Remove PATH entry from .bashrc ───────────────────────────────

echo -e "\n${CYAN}========================================"
echo -e "Cleaning up shell configuration"
echo -e "========================================${NC}"

BASHRC="$HOME/.bashrc"
if [[ -f "$BASHRC" ]]; then
    # Remove the "# Kiro CLI" comment and the PATH export line added by the installer
    if grep -q '# Kiro CLI' "$BASHRC" 2>/dev/null; then
        if [[ "$OSTYPE" == "darwin"* ]]; then
            sed -i "" '/^# Kiro CLI$/d' "$BASHRC"
        else
            sed -i '/^# Kiro CLI$/d' "$BASHRC"
        fi
        echo -e "${GREEN}Removed Kiro CLI comment from ${BASHRC}${NC}"
    fi
    # Note: we don't remove the .local/bin PATH line since other tools may use it
    echo -e "${YELLOW}Note: ~/.local/bin PATH entry was not removed (may be used by other tools).${NC}"
else
    echo -e "${YELLOW}${BASHRC} not found, skipping shell cleanup.${NC}"
fi

# ── Verify ───────────────────────────────────────────────────────

echo -e "\n${CYAN}========================================"
echo -e "Verifying uninstall"
echo -e "========================================${NC}"

if command_exists kiro-cli; then
    KIRO_PATH=$(command -v kiro-cli)
    echo -e "${YELLOW}kiro-cli command still present at: ${KIRO_PATH}${NC}"
    echo -e "${YELLOW}You may need to remove it from your PATH or restart your shell.${NC}"
else
    echo -e "${GREEN}Kiro CLI command not found. Uninstall appears complete.${NC}"
fi

echo -e "\n${GREEN}========================================"
echo -e "Uninstallation process completed!"
echo -e "========================================${NC}"
