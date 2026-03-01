#!/usr/bin/env bash
# =============================================================================
# Uninstall Starship - Removes Starship binary and optionally its config
# =============================================================================
# Usage: ./uninstall-starship.sh [--purge] [-h|--help]
#
# Removes the Starship binary. With --purge, also removes the config file
# without prompting.
#
# Options:
#   --purge       Also remove ~/.config/starship.toml without prompting
#   -h, --help    Show this help message
# =============================================================================

set -euo pipefail

# ── Colors ──────────────────────────────────────────────────────────
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
DIM='\033[2m'
BOLD='\033[1m'
RESET='\033[0m'

PASS="${GREEN}✔${RESET}"
FAIL="${RED}✘${RESET}"
ARROW="${BLUE}▸${RESET}"

# ── Helpers ─────────────────────────────────────────────────────────
step()    { printf "  ${ARROW} %-46s" "$1"; }
pass()    { echo -e "${PASS}  ${DIM}${1:-}${RESET}"; }
fail()    { echo -e "${FAIL}  ${RED}${1}${RESET}"; }

show_help() {
    cat << 'EOF'
Usage: ./uninstall-starship.sh [OPTIONS]

Removes the Starship prompt binary and optionally its configuration.

OPTIONS:
    --purge       Also remove ~/.config/starship.toml without prompting
    -h, --help    Show this help message
EOF
}

# ── Parse arguments ─────────────────────────────────────────────────
PURGE=false

while [[ $# -gt 0 ]]; do
    case $1 in
        -h|--help)   show_help; exit 0 ;;
        --purge)     PURGE=true; shift ;;
        *)
            echo -e "${RED}Unknown option: $1${RESET}" >&2
            show_help
            exit 1
            ;;
    esac
done

# ── Header ──────────────────────────────────────────────────────────
echo ""
echo -e "${BOLD}  Uninstall Starship${RESET}"
echo -e "  ${DIM}$(printf '─%.0s' {1..46})${RESET}"
echo ""

# ── Locate binary ──────────────────────────────────────────────────
starship_bin=""
if command -v starship &>/dev/null; then
    starship_bin="$(command -v starship)"
elif [[ -f /usr/local/bin/starship ]]; then
    starship_bin="/usr/local/bin/starship"
fi

step "locate starship"
if [[ -z "$starship_bin" ]]; then
    fail "not found - nothing to uninstall"
    echo ""
    exit 0
fi
version=$(starship --version 2>/dev/null | head -1 | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' || echo "unknown")
pass "v${version} at ${starship_bin}"

# ── Remove binary ──────────────────────────────────────────────────
step "remove binary"
needs_sudo=false
if [[ ! -w "$(dirname "$starship_bin")" ]]; then
    needs_sudo=true
fi

if [[ "$needs_sudo" == true ]]; then
    if sudo rm -f "$starship_bin"; then
        pass "removed (sudo)"
    else
        fail "could not remove ${starship_bin}"
        exit 1
    fi
else
    if rm -f "$starship_bin"; then
        pass "removed"
    else
        fail "could not remove ${starship_bin}"
        exit 1
    fi
fi

# ── Handle config file ─────────────────────────────────────────────
config_path="$HOME/.config/starship.toml"
if [[ -f "$config_path" ]]; then
    if [[ "$PURGE" == true ]]; then
        step "remove config"
        rm -f "$config_path"
        pass "removed ${config_path}"
    else
        step "config file"
        echo -e "${YELLOW}!${RESET}  ${DIM}${config_path} kept (use --purge to remove)${RESET}"
        if [[ -t 0 ]]; then
            read -r -p "  Remove ${config_path}? (y/n): " answer
            if [[ "$answer" == "y" ]]; then
                rm -f "$config_path"
                echo -e "  ${PASS}  ${DIM}removed${RESET}"
            else
                echo -e "  ${DIM}kept${RESET}"
            fi
        fi
    fi
fi

# ── Verify removal ─────────────────────────────────────────────────
step "verify removal"
if command -v starship &>/dev/null; then
    fail "starship still found at $(command -v starship)"
else
    pass "starship removed from PATH"
fi

# ── Reminder ────────────────────────────────────────────────────────
echo ""
echo -e "  ${DIM}$(printf '─%.0s' {1..46})${RESET}"
echo ""
echo -e "  ${GREEN}${BOLD}Starship uninstalled.${RESET}"
echo ""
echo -e "  ${DIM}Remember to remove the init line from your shell config:${RESET}"
echo ""
echo -e "  ${ARROW} ${BOLD}~/.bashrc${RESET}:              eval \"\$(starship init bash)\""
echo -e "  ${ARROW} ${BOLD}~/.zshrc${RESET}:               eval \"\$(starship init zsh)\""
echo -e "  ${ARROW} ${BOLD}~/.config/fish/config.fish${RESET}: starship init fish | source"
echo ""
