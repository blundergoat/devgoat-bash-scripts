#!/usr/bin/env bash
# =============================================================================
# Install Bats Core - Installs bats-core for running the test suite
# =============================================================================
# Usage: ./lib/setup/install-bats-core.sh [-h|--help]
#
# Installs bats-core (Bash Automated Testing System) via apt, Homebrew, or npm
# depending on what's available. After install, run the test suite with:
#
#   bats tests/ --recursive
#
# =============================================================================

set -euo pipefail

# -- Colors -------------------------------------------------------------------
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
DIM='\033[2m'
BOLD='\033[1m'
RESET='\033[0m'

PASS="${GREEN}✔${RESET}"
FAIL="${RED}✘${RESET}"
ARROW="${BLUE}▸${RESET}"

# -- Helpers ------------------------------------------------------------------
step()    { printf "  ${ARROW} %-46s" "$1"; }
pass()    { echo -e "${PASS}  ${DIM}${1:-}${RESET}"; }
fail()    { echo -e "${FAIL}  ${RED}${1}${RESET}"; }

show_help() {
    cat << 'EOF_HELP'
Usage: ./lib/setup/install-bats-core.sh [OPTIONS]

Installs bats-core (Bash Automated Testing System) for running the test suite.

Tries these install methods in order:
  1. sudo apt-get install bats   (Debian/Ubuntu package for bats-core)
  2. brew install bats-core      (macOS/Linuxbrew)
  3. npm install -g bats         (fallback package that provides `bats`)

OPTIONS:
    -h, --help    Show this help message

AFTER INSTALL:
    bats tests/ --recursive          # Run all tests
    bats tests/conventions/          # Run convention tests only
    bats tests/common/               # Run _common.sh unit tests only

SEE ALSO:
    docs/bats-core.md    Full test suite documentation
EOF_HELP
}

# -- Argument parsing ----------------------------------------------------------
while [[ $# -gt 0 ]]; do
    case $1 in
        -h|--help)
            show_help
            exit 0
            ;;
        -*)
            echo -e "${RED}Unknown option: $1${RESET}" >&2
            show_help
            exit 1
            ;;
        *)
            echo -e "${RED}Unexpected argument: $1${RESET}" >&2
            show_help
            exit 1
            ;;
    esac
done

# -- Header -------------------------------------------------------------------
echo ""
echo -e "${BOLD}  Install Bats Core${RESET}"
echo -e "  ${DIM}$(printf '─%.0s' {1..46})${RESET}"
echo ""

# -- Check if already installed ------------------------------------------------
step "bats"
if command -v bats &>/dev/null; then
    version=$(bats --version 2>/dev/null | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' || echo "unknown")
    bats_path=$(command -v bats)
    pass "v${version} already installed at ${bats_path}"
    echo ""
    echo -e "  ${DIM}Run tests:${RESET}  bats tests/ --recursive"
    echo ""
    exit 0
fi
echo -e "${DIM}not found${RESET}"

# -- Install ------------------------------------------------------------------
installed=false

# Method 1: apt (Debian/Ubuntu package name is `bats`, project is bats-core)
if ! $installed && command -v apt-get &>/dev/null; then
    step "sudo apt-get install bats"
    if sudo apt-get install -y bats >/dev/null 2>&1; then
        version=$(bats --version 2>/dev/null | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' || echo "unknown")
        pass "v${version}"
        installed=true
    else
        fail "apt install failed"
    fi
fi

# Method 2: Homebrew
if ! $installed && command -v brew &>/dev/null; then
    step "brew install bats-core"
    if brew install bats-core >/dev/null 2>&1; then
        version=$(bats --version 2>/dev/null | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' || echo "unknown")
        pass "v${version}"
        installed=true
    else
        fail "brew install failed"
    fi
fi

# Method 3: npm fallback
if ! $installed && command -v npm &>/dev/null; then
    step "npm install -g bats"
    if npm install -g bats >/dev/null 2>&1; then
        version=$(bats --version 2>/dev/null | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' || echo "unknown")
        pass "v${version}"
        installed=true
    else
        fail "npm install failed"
    fi
fi

# -- Result -------------------------------------------------------------------
echo ""
echo -e "  ${DIM}$(printf '─%.0s' {1..46})${RESET}"
echo ""

if $installed; then
    echo -e "  ${GREEN}${BOLD}bats-core installed${RESET}"
    echo ""
    echo -e "  ${DIM}Run tests:${RESET}  bats tests/ --recursive"
    echo ""
else
    echo -e "  ${RED}${BOLD}Could not install bats-core${RESET}"
    echo ""
    echo -e "  ${DIM}Install manually:${RESET}"
    echo "    sudo apt install bats        # Debian/Ubuntu package for bats-core"
    echo "    brew install bats-core      # macOS/Linuxbrew"
    echo "    npm install -g bats         # fallback"
    echo "    https://github.com/bats-core/bats-core#installation"
    echo ""
    exit 1
fi
