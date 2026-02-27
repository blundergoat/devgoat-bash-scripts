e out #!/usr/bin/env bash
# =============================================================================
# Stacks Common Bootstrap
# =============================================================================
# Shared helpers for all stacks/ scripts. Source this at the top of every script:
#
#   source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/../_common.sh"
#
# Provides:
#   - Color constants and symbols
#   - Counters and failure tracking
#   - step/pass/fail/skip/warn helpers (preflight/verify style)
#   - log_info/log_ok/log_warn/log_error helpers (database/Go style)
#   - header/divider/summary formatting
#   - elapsed_since() timing
#   - PROJECT_ROOT detection
#   - .env auto-loading
# =============================================================================

# ── Double-source guard ──────────────────────────────────────────
[[ -n "${_STACKS_COMMON_LOADED:-}" ]] && return 0
_STACKS_COMMON_LOADED=1

# ── Colors ───────────────────────────────────────────────────────
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
# shellcheck disable=SC2034
CYAN='\033[0;36m'
DIM='\033[2m'
BOLD='\033[1m'
RESET='\033[0m'
NC='\033[0m'

# ── Symbols ──────────────────────────────────────────────────────
PASS="${GREEN}✔${RESET}"
FAIL="${RED}✘${RESET}"
SKIP="${YELLOW}○${RESET}"
ARROW="${BLUE}▸${RESET}"

# ── Counters ─────────────────────────────────────────────────────
TOTAL=0
PASSED=0
FAILED=0
ERRORS=0
WARNINGS=0
FAILURES=()

# Detect nanosecond support (GNU date has %N, BSD/macOS does not)
if date +%s%N 2>/dev/null | grep -q 'N'; then
    _GOAT_TIME_NS=false
else
    _GOAT_TIME_NS=true
fi

_goat_now() {
    if [[ "$_GOAT_TIME_NS" == true ]]; then
        date +%s%N
    else
        date +%s
    fi
}

START_TIME=$(_goat_now)

# ── PROJECT_ROOT detection ───────────────────────────────────────
if [[ -z "${PROJECT_ROOT:-}" ]]; then
    PROJECT_ROOT="$(git -C "$(dirname "${BASH_SOURCE[0]}")" rev-parse --show-toplevel 2>/dev/null || cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
fi

# ── .env loader (safe key=value parsing, no shell execution) ─────
if [[ -f "$PROJECT_ROOT/.env" ]]; then
    while IFS='=' read -r key value; do
        # Skip blank lines and comments
        [[ -z "$key" || "$key" =~ ^[[:space:]]*# ]] && continue
        # Trim leading whitespace from key
        key="${key#"${key%%[![:space:]]*}"}"
        # Strip surrounding quotes from value
        value="${value%\"}"
        value="${value#\"}"
        value="${value%\'}"
        value="${value#\'}"
        export "$key=$value"
    done < "$PROJECT_ROOT/.env"
fi

# ── Preflight/Verify helpers ─────────────────────────────────────
step() {
    TOTAL=$((TOTAL + 1))
    printf "  ${ARROW} %-44s" "$1"
}

pass() {
    local detail="${1:-}"
    PASSED=$((PASSED + 1))
    if [[ -n "$detail" ]]; then
        echo -e "${PASS}  ${DIM}${detail}${RESET}"
    else
        echo -e "${PASS}"
    fi
}

fail() {
    local msg="$1"
    FAILED=$((FAILED + 1))
    ERRORS=$((ERRORS + 1))
    FAILURES+=("$msg")
    echo -e "${FAIL}  ${RED}${msg}${RESET}"
}

skip() {
    local reason="${1:-skipped}"
    echo -e "${SKIP}  ${DIM}${reason}${RESET}"
}

warn() {
    local msg="$1"
    WARNINGS=$((WARNINGS + 1))
    echo -e "${YELLOW}⚠${RESET}  ${DIM}${msg}${RESET}"
}

header() {
    local title="$1"
    echo ""
    echo -e "${BOLD}  ${title}${RESET}"
    echo -e "  ${DIM}$(printf '─%.0s' {1..44})${RESET}"
    echo ""
}

section() {
    echo ""
    echo -e "  ${BOLD}$1${RESET}"
    echo ""
}

divider() {
    echo -e "  ${DIM}$(printf '─%.0s' {1..44})${RESET}"
}

summary() {
    local end_time
    end_time=$(_goat_now)
    local total_ms
    if [[ "$_GOAT_TIME_NS" == true ]]; then
        total_ms=$(( (end_time - START_TIME) / 1000000 ))
    else
        total_ms=$(( (end_time - START_TIME) * 1000 ))
    fi
    local total_secs=$((total_ms / 1000))
    local total_frac=$((total_ms % 1000 / 100))

    echo ""
    divider

    if [[ $FAILED -eq 0 ]]; then
        echo ""
        echo -e "  ${GREEN}${BOLD}All ${PASSED}/${TOTAL} checks passed${RESET}  ${DIM}(${total_secs}.${total_frac}s)${RESET}"
        echo ""
    else
        echo ""
        echo -e "  ${RED}${BOLD}${FAILED}/${TOTAL} checks failed${RESET}  ${DIM}(${total_secs}.${total_frac}s)${RESET}"
        echo ""
        for f in "${FAILURES[@]}"; do
            echo -e "    ${FAIL}  ${f}"
        done
        echo ""
        exit 1
    fi
}

elapsed_since() {
    local start=$1
    local end
    end=$(_goat_now)
    local ms
    if [[ "$_GOAT_TIME_NS" == true ]]; then
        ms=$(( (end - start) / 1000000 ))
    else
        ms=$(( (end - start) * 1000 ))
    fi
    if [[ $ms -lt 1000 ]]; then
        echo "${ms}ms"
    else
        local secs=$((ms / 1000))
        local frac=$((ms % 1000 / 100))
        echo "${secs}.${frac}s"
    fi
}

# ── Database/Go-style log helpers ────────────────────────────────
log_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
log_ok()   { echo -e "${GREEN}[OK]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error(){ echo -e "${RED}[ERROR]${NC} $1"; }
