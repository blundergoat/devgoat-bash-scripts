#!/usr/bin/env bash
# =============================================================================
# Install Starship - Installs Starship cross-shell prompt
# =============================================================================
# Usage: ./install-starship.sh [--force] [--config] [-h|--help]
#
# Installs Starship via the official install script. Starship is a minimal,
# fast, and customizable prompt that works with any shell.
#
# Options:
#   --force       Reinstall even if Starship is already installed
#   --config      Create a starter ~/.config/starship.toml if one doesn't exist
#   -h, --help    Show this help message
# =============================================================================

set -euo pipefail

# ── Colors ──────────────────────────────────────────────────────────
RED='\033[0;31m'
GREEN='\033[0;32m'
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
Usage: ./install-starship.sh [OPTIONS]

Installs Starship cross-shell prompt via the official install script.

OPTIONS:
    --force       Reinstall even if Starship is already installed
    --config      Create a starter ~/.config/starship.toml if missing
    -h, --help    Show this help message

AFTER INSTALL:
    Add the init line to your shell config (printed after install).

SEE ALSO:
    https://starship.rs/
EOF
}

# ── Parse arguments ─────────────────────────────────────────────────
FORCE_INSTALL=false
CREATE_CONFIG=false

while [[ $# -gt 0 ]]; do
    case $1 in
        -h|--help)   show_help; exit 0 ;;
        --force)     FORCE_INSTALL=true; shift ;;
        --config)    CREATE_CONFIG=true; shift ;;
        *)
            echo -e "${RED}Unknown option: $1${RESET}" >&2
            show_help
            exit 1
            ;;
    esac
done

# ── Header ──────────────────────────────────────────────────────────
echo ""
echo -e "${BOLD}  Install Starship${RESET}"
echo -e "  ${DIM}$(printf '─%.0s' {1..46})${RESET}"
echo ""

# ── Check if already installed ──────────────────────────────────────
step "starship"
if command -v starship &>/dev/null && [[ "$FORCE_INSTALL" != true ]]; then
    version=$(starship --version 2>/dev/null | head -1 | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' || echo "unknown")
    pass "v${version} already installed"
    echo ""
    echo -e "  ${DIM}Use --force to reinstall.${RESET}"
    echo ""
    exit 0
fi
echo -e "${DIM}installing...${RESET}"

# ── Prerequisites ───────────────────────────────────────────────────
step "curl"
if command -v curl &>/dev/null; then
    pass
else
    fail "not found - required for install"
    exit 1
fi

# ── Install Starship ────────────────────────────────────────────────
step "downloading & installing"
if curl -sS https://starship.rs/install.sh | sh -s -- --yes >/dev/null 2>&1; then
    pass
else
    fail "install failed"
    echo ""
    echo -e "  ${DIM}Try manually: https://starship.rs/guide/#step-1-install-starship${RESET}"
    echo ""
    exit 1
fi

# ── Verify install ──────────────────────────────────────────────────
step "verify binary"
if command -v starship &>/dev/null; then
    version=$(starship --version 2>/dev/null | head -1 | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' || echo "unknown")
    pass "v${version}"
else
    fail "starship not found on PATH after install"
    exit 1
fi

# ── Create starter config ──────────────────────────────────────────
if [[ "$CREATE_CONFIG" == true ]]; then
    config_path="$HOME/.config/starship.toml"
    step "starter config"
    if [[ -f "$config_path" ]]; then
        pass "already exists at ${config_path}"
    else
        mkdir -p "$HOME/.config"
        cat > "$config_path" << 'TOML'
# Starship configuration
# Full reference: https://starship.rs/config/

format = """
$username\
$hostname\
$directory\
$git_branch\
$git_status\
$cmd_duration\
$line_break\
$character"""

[character]
success_symbol = "[❯](bold green)"
error_symbol = "[❯](bold red)"

[git_branch]
symbol = " "

[directory]
truncation_length = 3
TOML
        pass "created ${config_path}"
    fi
fi

# ── Shell init instructions ─────────────────────────────────────────
echo ""
echo -e "  ${DIM}$(printf '─%.0s' {1..46})${RESET}"
echo ""
echo -e "  ${GREEN}${BOLD}Starship installed!${RESET}"
echo ""
echo -e "  ${DIM}Add the init line to your shell config:${RESET}"
echo ""

current_shell="$(basename "${SHELL:-bash}")"
case "$current_shell" in
    bash)
        echo -e "  ${ARROW} ${BOLD}Bash${RESET} ${DIM}(detected)${RESET}  Add to ${BOLD}~/.bashrc${RESET}:"
        echo -e "    eval \"\$(starship init bash)\""
        ;;
    zsh)
        echo -e "  ${ARROW} ${BOLD}Zsh${RESET} ${DIM}(detected)${RESET}  Add to ${BOLD}~/.zshrc${RESET}:"
        echo -e "    eval \"\$(starship init zsh)\""
        ;;
    fish)
        echo -e "  ${ARROW} ${BOLD}Fish${RESET} ${DIM}(detected)${RESET}  Add to ${BOLD}~/.config/fish/config.fish${RESET}:"
        echo -e "    starship init fish | source"
        ;;
    *)
        echo -e "  ${ARROW} ${BOLD}Bash${RESET}  Add to ${BOLD}~/.bashrc${RESET}:"
        echo -e "    eval \"\$(starship init bash)\""
        echo -e "  ${ARROW} ${BOLD}Zsh${RESET}   Add to ${BOLD}~/.zshrc${RESET}:"
        echo -e "    eval \"\$(starship init zsh)\""
        echo -e "  ${ARROW} ${BOLD}Fish${RESET}  Add to ${BOLD}~/.config/fish/config.fish${RESET}:"
        echo -e "    starship init fish | source"
        ;;
esac
echo ""
