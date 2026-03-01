#!/usr/bin/env bash
# =============================================================================
# devgoat-bash-scripts Preflight Checks - repo-level quality gate
# =============================================================================
# Usage: ./preflight-checks.sh [--fix] [-h|--help]
# =============================================================================

set -euo pipefail

# ── Colors ───────────────────────────────────────────────────────
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
DIM='\033[2m'
BOLD='\033[1m'
RESET='\033[0m'

# ── Symbols ──────────────────────────────────────────────────────
PASS_SYM="${GREEN}✔${RESET}"
FAIL_SYM="${RED}✘${RESET}"
SKIP_SYM="${YELLOW}○${RESET}"
ARROW="${BLUE}▸${RESET}"

# ── Counters ─────────────────────────────────────────────────────
TOTAL=0
PASSED=0
FAILED=0
ERRORS=0
FAILURES=()
# Detect nanosecond support (GNU date has %N, BSD/macOS does not)
if date +%s%N 2>/dev/null | grep -q 'N'; then
    _GOAT_TIME_NS=false
else
    _GOAT_TIME_NS=true
fi
_goat_now() {
    if [[ "$_GOAT_TIME_NS" == true ]]; then date +%s%N; else date +%s; fi
}
START_TIME=$(_goat_now)

# ── Helpers ──────────────────────────────────────────────────────
step() {
    TOTAL=$((TOTAL + 1))
    printf "  ${ARROW} %-44s" "$1"
}

pass() {
    local detail="${1:-}"
    PASSED=$((PASSED + 1))
    if [[ -n "$detail" ]]; then
        echo -e "${PASS_SYM}  ${DIM}${detail}${RESET}"
    else
        echo -e "${PASS_SYM}"
    fi
}

fail() {
    local msg="$1"
    FAILED=$((FAILED + 1))
    ERRORS=$((ERRORS + 1))
    FAILURES+=("$msg")
    echo -e "${FAIL_SYM}  ${RED}${msg}${RESET}"
}

skip() {
    local reason="${1:-skipped}"
    echo -e "${SKIP_SYM}  ${DIM}${reason}${RESET}"
}

warn() {
    local msg="$1"
    echo -e "${YELLOW}⚠${RESET}  ${DIM}${msg}${RESET}"
}

header() {
    local title="$1"
    echo ""
    echo -e "${BOLD}  ${title}${RESET}"
    echo -e "  ${DIM}$(printf '─%.0s' {1..44})${RESET}"
    echo ""
}

divider() {
    echo -e "  ${DIM}$(printf '─%.0s' {1..44})${RESET}"
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
            echo -e "    ${FAIL_SYM}  ${f}"
        done
        echo ""
        exit 1
    fi
}

show_help() {
    cat << EOF
Usage: $(basename "$0") [OPTIONS]

Repo-level quality gate for devgoat-bash-scripts. Checks all .sh files under lib/
for conventions, syntax, and common mistakes.

Checks performed:
  1. Shebang line       - #!/usr/bin/env bash present
  2. Strict mode        - set -euo pipefail (or -uo for known exceptions)
  3. Executable bit     - chmod +x on all .sh files
  4. Bash syntax        - bash -n on all .sh files
  5. Shellcheck         - shellcheck -x (skipped if not installed)
  6. No secrets         - no .env, credentials, or key files staged
  7. Bats tests         - bats tests/ --recursive (auto-installs bats-core if missing)

OPTIONS:
    -h, --help    Show this help message
    --fix         Auto-fix executable bits (runs make-scripts-executable.sh)

EXIT CODES:
    0   All checks passed
    1   One or more checks failed

EXAMPLES:
    $(basename "$0")           # Run all checks
    $(basename "$0") --fix     # Fix executable bits, then run checks
EOF
}

# ── Repo root & script discovery ─────────────────────────────────
REPO_ROOT="$(git -C "$(dirname "$0")" rev-parse --show-toplevel)"
FIX_MODE=false

# ── Argument parsing ─────────────────────────────────────────────
while [[ $# -gt 0 ]]; do
    case $1 in
        -h|--help)
            show_help
            exit 0
            ;;
        --fix)
            FIX_MODE=true
            shift
            ;;
        -*)
            echo "Unknown option: $1" >&2
            show_help
            exit 1
            ;;
        *)
            echo "Unexpected argument: $1" >&2
            show_help
            exit 1
            ;;
    esac
done

# ── Auto-fix pass ────────────────────────────────────────────────
if [[ "$FIX_MODE" == true ]]; then
    fix_script="$REPO_ROOT/lib/maintenance/make-scripts-executable.sh"
    if [[ -x "$fix_script" ]]; then
        echo -e "  ${ARROW} Running make-scripts-executable.sh ..."
        "$fix_script"
        echo ""
    else
        echo "make-scripts-executable.sh not found or not executable" >&2
        exit 1
    fi
fi

# ── Collect scripts ──────────────────────────────────────────────
SCRIPTS=()
while IFS= read -r -d '' file; do
    SCRIPTS+=("$file")
done < <(find "$REPO_ROOT/lib" -name "*.sh" -type f -print0 2>/dev/null | sort -z)

if [[ ${#SCRIPTS[@]} -eq 0 ]]; then
    echo "No .sh files found under lib/" >&2
    exit 1
fi

# Known exceptions: scripts that intentionally omit -e (use set -uo pipefail)
# - stacks verify/preflight: must continue past individual check failures
# - health checks: must report all failures, not stop at first
# - _common.sh libraries: sourced, not executed directly
STRICT_EXCEPTIONS=(
    "lib/stacks/php/verify.sh"
    "lib/stacks/php/preflight-checks.sh"
    "lib/stacks/python/verify.sh"
    "lib/stacks/python/preflight-checks.sh"
    "lib/stacks/node/verify.sh"
    "lib/stacks/node/preflight-checks.sh"
    "lib/stacks/rust/verify.sh"
    "lib/stacks/rust/preflight-checks.sh"
    "lib/health/check-gpu.sh"
    "lib/ai-cli/_common.sh"
    "lib/stacks/_common.sh"
)

is_strict_exception() {
    local rel_path="$1"
    for exception in "${STRICT_EXCEPTIONS[@]}"; do
        if [[ "$rel_path" == "$exception" ]]; then
            return 0
        fi
    done
    return 1
}

# ── Checks ───────────────────────────────────────────────────────
header "Preflight Checks - devgoat-bash-scripts"
echo -e "  ${DIM}$(date '+%Y-%m-%d %H:%M:%S')  (${#SCRIPTS[@]} scripts)${RESET}"
echo ""

# 1. Shebang
step "Shebang (#!/usr/bin/env bash)"
t=$(_goat_now)
shebang_failures=()
for file in "${SCRIPTS[@]}"; do
    first_line=$(head -n 1 "$file")
    if [[ "$first_line" != "#!/usr/bin/env bash" ]]; then
        rel="${file#"$REPO_ROOT/"}"
        shebang_failures+=("$rel")
    fi
done
if [[ ${#shebang_failures[@]} -eq 0 ]]; then
    pass "$(elapsed_since "$t")"
else
    fail "Shebang missing in ${#shebang_failures[@]} file(s)"
    for f in "${shebang_failures[@]}"; do
        echo -e "    ${DIM}${f}${RESET}"
    done
fi

# 2. Strict mode
step "Strict mode (set -euo pipefail)"
t=$(_goat_now)
strict_failures=()
for file in "${SCRIPTS[@]}"; do
    rel="${file#"$REPO_ROOT/"}"
    content=$(head -n 50 "$file")

    if is_strict_exception "$rel"; then
        # Exceptions must have at least set -uo pipefail
        if ! echo "$content" | grep -qE '^set -uo pipefail'; then
            # Libraries (_common.sh) may not need any set at all - skip them
            case "$rel" in
                */_common.sh) ;;
                *) strict_failures+=("$rel (expected set -uo pipefail)") ;;
            esac
        fi
    else
        if ! echo "$content" | grep -qE '^set -euo pipefail'; then
            strict_failures+=("$rel")
        fi
    fi
done
if [[ ${#strict_failures[@]} -eq 0 ]]; then
    pass "$(elapsed_since "$t")"
else
    fail "Strict mode missing in ${#strict_failures[@]} file(s)"
    for f in "${strict_failures[@]}"; do
        echo -e "    ${DIM}${f}${RESET}"
    done
fi

# 3. Executable bit
step "Executable bit (chmod +x)"
t=$(_goat_now)
exec_failures=()
for file in "${SCRIPTS[@]}"; do
    if [[ ! -x "$file" ]]; then
        rel="${file#"$REPO_ROOT/"}"
        exec_failures+=("$rel")
    fi
done
if [[ ${#exec_failures[@]} -eq 0 ]]; then
    pass "$(elapsed_since "$t")"
else
    fail "Not executable: ${#exec_failures[@]} file(s)"
    for f in "${exec_failures[@]}"; do
        echo -e "    ${DIM}${f}${RESET}"
    done
    if [[ "$FIX_MODE" != true ]]; then
        echo -e "    ${DIM}Tip: re-run with --fix to auto-fix${RESET}"
    fi
fi

# 4. Bash syntax (bash -n)
step "Bash syntax (bash -n)"
t=$(_goat_now)
syntax_failures=()
for file in "${SCRIPTS[@]}"; do
    if ! bash -n "$file" 2>/dev/null; then
        rel="${file#"$REPO_ROOT/"}"
        syntax_failures+=("$rel")
    fi
done
if [[ ${#syntax_failures[@]} -eq 0 ]]; then
    pass "${#SCRIPTS[@]} files $(elapsed_since "$t")"
else
    fail "Syntax errors in ${#syntax_failures[@]} file(s)"
    for f in "${syntax_failures[@]}"; do
        echo -e "    ${DIM}${f}${RESET}"
    done
fi

# 5. Shellcheck
step "Shellcheck"
t=$(_goat_now)
if ! command -v shellcheck &>/dev/null; then
    echo -e "    ${DIM}shellcheck not found; attempting install...${RESET}"
    if command -v apt-get &>/dev/null; then
        sudo apt-get install -y shellcheck >/dev/null 2>&1
    elif command -v brew &>/dev/null; then
        brew install shellcheck >/dev/null 2>&1
    fi
    if ! command -v shellcheck &>/dev/null; then
        skip "shellcheck not installed - install manually: sudo apt install shellcheck | brew install shellcheck"
    fi
fi
if command -v shellcheck &>/dev/null; then
    sc_failures=()
    for file in "${SCRIPTS[@]}"; do
        if ! shellcheck -x -S warning "$file" &>/dev/null; then
            rel="${file#"$REPO_ROOT/"}"
            sc_failures+=("$rel")
        fi
    done
    if [[ ${#sc_failures[@]} -eq 0 ]]; then
        pass "${#SCRIPTS[@]} files $(elapsed_since "$t")"
    else
        fail "Shellcheck warnings in ${#sc_failures[@]} file(s)"
        for f in "${sc_failures[@]}"; do
            echo -e "    ${DIM}${f}${RESET}"
        done
    fi
fi

# 6. No secrets staged
step "No secrets staged"
t=$(_goat_now)
if ! git -C "$REPO_ROOT" rev-parse --git-dir &>/dev/null; then
    skip "not a git repository"
else
    staged_files=$(git -C "$REPO_ROOT" diff --cached --name-only 2>/dev/null || true)
    secret_hits=()
    if [[ -n "$staged_files" ]]; then
        while IFS= read -r sfile; do
            case "$sfile" in
                *.env|*.env.*|*.pem|*.key)
                    secret_hits+=("$sfile")
                    ;;
                *credentials*|*secret*)
                    # Skip shell scripts - these manage secrets, they aren't secrets
                    [[ "$sfile" == *.sh ]] && continue
                    secret_hits+=("$sfile")
                    ;;
            esac
        done <<< "$staged_files"
    fi
    if [[ ${#secret_hits[@]} -eq 0 ]]; then
        pass "$(elapsed_since "$t")"
    else
        fail "Suspicious staged files: ${#secret_hits[@]}"
        for f in "${secret_hits[@]}"; do
            echo -e "    ${DIM}${f}${RESET}"
        done
    fi
fi

# 7. Bats tests
step "Bats tests (tests/)"
t=$(_goat_now)
if ! command -v bats &>/dev/null; then
    skip "bats not installed"
    echo -e "    ${DIM}Install: sudo apt install bats-core | brew install bats-core | ./lib/tools/install-bats-core.sh${RESET}"
else
    if bats tests/ --recursive </dev/null; then
        pass "$(elapsed_since "$t")"
    else
        fail "Bats tests failed"
    fi
fi

# ── Summary ──────────────────────────────────────────────────────
summary
