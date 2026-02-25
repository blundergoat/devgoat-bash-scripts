#!/usr/bin/env bash
# GOAT System Installer - Kiro CLI
#
# WARNING: Only install on systems you own or have permission to modify.
# This script is for personal development environments only.
#
# Installs Kiro CLI via the official curl installer from https://cli.kiro.dev/install.
# Run this script in WSL or any Unix-like terminal.

set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/_common.sh"

show_help() {
    echo ""
    echo -e "${CYAN}Kiro CLI Installer${NC}"
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

block_gitbash "Kiro CLI installer"

echo -e "${CYAN}Starting Kiro CLI installation...${NC}"
echo -e "${YELLOW}Installer: ${WHITE}https://cli.kiro.dev/install${NC}"
print_platform

# ── Prerequisites ─────────────────────────────────────────────────

if ! command_exists curl; then
    echo -e "${RED}curl is required to download the installer.${NC}"
    echo -e "${YELLOW}Install curl and rerun.${NC}"
    exit 1
fi

if ! command_exists unzip; then
    echo -e "${YELLOW}Installing required dependency: unzip...${NC}"
    if command_exists apt; then
        sudo apt-get update -qq && sudo apt-get install -y unzip
    elif command_exists yum; then
        sudo yum install -y unzip
    elif command_exists dnf; then
        sudo dnf install -y unzip
    elif command_exists pacman; then
        sudo pacman -S unzip --noconfirm
    elif command_exists brew; then
        brew install unzip
    else
        echo -e "${RED}Could not install unzip. Please install it manually.${NC}"
        exit 1
    fi
fi

# ── Install ───────────────────────────────────────────────────────

echo -e "\n${CYAN}========================================"
echo -e "Installing Kiro CLI"
echo -e "========================================${NC}"

curl -fsSL https://cli.kiro.dev/install | bash

# ── PATH setup ────────────────────────────────────────────────────

BASHRC="$HOME/.bashrc"
PATH_EXPORT='export PATH="$HOME/.local/bin:$PATH"'

if [[ -f "$BASHRC" ]]; then
    if ! grep -q '.local/bin' "$BASHRC"; then
        echo "" >> "$BASHRC"
        echo "# Kiro CLI" >> "$BASHRC"
        echo "$PATH_EXPORT" >> "$BASHRC"
        echo -e "${GREEN}Added Kiro CLI to PATH in ${BASHRC}${NC}"
    else
        echo -e "${YELLOW}PATH already configured in ${BASHRC}${NC}"
    fi
fi

export PATH="$HOME/.local/bin:$PATH"

# ── Verify ────────────────────────────────────────────────────────

echo -e "\n${YELLOW}Verifying installation...${NC}"
if verify_native_binary kiro-cli "Kiro CLI"; then
    echo -e "${GREEN}Kiro CLI installed successfully!${NC}"
    kiro-cli --version 2>/dev/null || echo -e "${YELLOW}Version command not available yet${NC}"

    echo -e "\n${CYAN}========================================"
    echo -e "Next Steps:"
    echo -e "========================================${NC}"
    echo -e "${WHITE}1. Restart your terminal or run: source ~/.bashrc"
    echo -e "2. Start the CLI: kiro-cli"
    echo -e "3. Run kiro-cli --help for commands${NC}"
fi

echo -e "\n${GREEN}Installation process completed!${NC}"
