#!/usr/bin/env bash
# =============================================================================
# GitHub Token - Check and update GitHub authentication
# =============================================================================
# Usage:
#   ./lib/workflow/github-token.sh           # Check current token status
#   ./lib/workflow/github-token.sh --update  # Update token
#   ./lib/workflow/github-token.sh --setup   # Set up git profile (name, email, username)
#
# Checks:
#   1. Git profile (user.name, user.email, github.user)
#   2. Git credential helper configuration
#   3. Stored GitHub credentials in ~/.git-credentials
#   4. Token validity via GitHub API
#
# Prerequisites:
#   - Git installed
#   - Git credential helper configured (store, osxkeychain, etc.)
#
# Logging: Uses check() status-dashboard pattern (intentional divergence from
# sibling inline helpers — this script is a status checker, not a workflow tool).
# =============================================================================

set -euo pipefail

# --- Source env-detect.sh if available, otherwise define minimal standalone defaults ---
# env-detect.sh is an optional shared helper providing environment detection,
# colours, and the check() function. When absent, standalone defaults below apply.
_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [[ -f "$_SCRIPT_DIR/env-detect.sh" ]]; then
    # shellcheck source=/dev/null
    source "$_SCRIPT_DIR/env-detect.sh"
else
    # Colors
    RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
    BLUE='\033[0;34m'; CYAN='\033[0;36m'; DIM='\033[2m'
    BOLD='\033[1m'; RESET='\033[0m'

    # Check symbols
    _CHECK_PASS="${GREEN}✔${RESET}"
    _CHECK_FAIL="${RED}✘${RESET}"
    _CHECK_WARN="${YELLOW}●${RESET}"
    _CHECK_INFO="${CYAN}ℹ${RESET}"
    _CHECK_ARROW="${BLUE}▸${RESET}"

    # Counters and padding
    CHECK_PAD=36
    TOTAL=0; PASSED=0; FAILED=0; WARNINGS=0

    # Check function
    check() {
        local label="$1" status="$2" detail="${3:-}"
        TOTAL=$((TOTAL + 1))
        local padded
        padded=$(printf "%-${CHECK_PAD}s" "$label")
        if [[ "$status" == "pass" ]]; then
            PASSED=$((PASSED + 1))
            echo -e "  ${_CHECK_ARROW} ${padded} ${_CHECK_PASS}  ${DIM}${detail}${RESET}"
        elif [[ "$status" == "warn" ]]; then
            WARNINGS=$((WARNINGS + 1))
            echo -e "  ${_CHECK_ARROW} ${padded} ${_CHECK_WARN}  ${YELLOW}${detail}${RESET}"
        elif [[ "$status" == "info" ]]; then
            echo -e "  ${_CHECK_ARROW} ${padded} ${_CHECK_INFO}  ${DIM}${detail}${RESET}"
        else
            FAILED=$((FAILED + 1))
            echo -e "  ${_CHECK_ARROW} ${padded} ${_CHECK_FAIL}  ${RED}${detail}${RESET}"
        fi
    }

    # Detect environment from directory structure (standalone fallback)
    ENV="${ENV:-standalone}"
fi

CHECK_PAD=36
CREDENTIALS_FILE="$HOME/.git-credentials"
GITHUB_HOST="github.com"
TOKEN_URL="https://github.com/settings/tokens/new?description=GitHub%20integration&scopes=repo%2Cgist%2Cread%3Aorg%2Cworkflow%2Cread%3Auser%2Cuser%3Aemail"

# --- show_help ---
show_help() {
    cat << EOF
Usage: $0 [OPTIONS]

Check and update GitHub authentication: token status, git profile,
credential helper, and API validation.

OPTIONS:
    (no args)       Check current GitHub token status
    --update, -u    Update GitHub token
    --setup,  -s    Set up git profile (name, email, username)
    -h, --help      Show this help message
EOF
}

# --- Parse arguments ---
ACTION="check"
while [[ $# -gt 0 ]]; do
    case $1 in
        --update|-u) ACTION="update"; shift ;;
        --setup|-s)  ACTION="setup"; shift ;;
        --help|-h)   show_help; exit 0 ;;
        *)
            echo "Unknown option: $1" >&2
            show_help
            exit 1
            ;;
    esac
done

# --- Prerequisite check ---
if ! command -v git &>/dev/null; then
    echo "git not found" >&2
    exit 1
fi

if ! command -v curl &>/dev/null; then
    echo "curl not found (required for token validation)" >&2
    exit 1
fi

# --- Cross-platform sed -i (macOS requires '' arg, Linux does not) ---
sed_inplace() {
    if [[ "$(uname)" == "Darwin" ]]; then
        sed -i '' "$@"
    else
        sed -i "$@"
    fi
}

# --- Extract current token from ~/.git-credentials ---
get_stored_token() {
    if [[ ! -f "$CREDENTIALS_FILE" ]]; then
        echo ""
        return
    fi
    # Format: https://user:token@github.com
    local line
    line=$(grep "$GITHUB_HOST" "$CREDENTIALS_FILE" 2>/dev/null | head -1)
    if [[ -z "$line" ]]; then
        echo ""
        return
    fi
    # Extract token (after : and before @)
    echo "$line" | sed -n 's|.*://[^:]*:\([^@]*\)@.*|\1|p'
}

# --- Extract username from ~/.git-credentials ---
get_stored_username() {
    if [[ ! -f "$CREDENTIALS_FILE" ]]; then
        echo ""
        return
    fi
    local line
    line=$(grep "$GITHUB_HOST" "$CREDENTIALS_FILE" 2>/dev/null | head -1)
    if [[ -z "$line" ]]; then
        echo ""
        return
    fi
    echo "$line" | sed -n 's|.*://\([^:]*\):.*@.*|\1|p'
}

# --- Resolve GitHub username (credentials file > git config) ---
resolve_github_username() {
    local cred_user
    cred_user=$(get_stored_username)
    if [[ -n "$cred_user" ]]; then
        echo "$cred_user"
        return
    fi
    local gh_user
    gh_user=$(git config --get github.user 2>/dev/null || echo "")
    if [[ -n "$gh_user" ]]; then
        echo "$gh_user"
        return
    fi
    echo ""
}

# --- Mask token for display ---
mask_token() {
    local token="$1"
    local len=${#token}
    if [[ $len -le 8 ]]; then
        echo "****"
    else
        echo "${token:0:4}...${token: -4}"
    fi
}

# --- Validate token and return details via GitHub API ---
# Returns: "valid|username|scopes" or "invalid||"
get_github_api_details() {
    local token="$1"

    # Single API call that captures headers (for scopes) and body (for login)
    local tmpheaders
    tmpheaders=$(mktemp)
    local body http_code
    body=$(curl -s -D "$tmpheaders" -w "\n%{http_code}" \
        -H "Authorization: token $token" \
        -H "Accept: application/vnd.github+json" \
        "https://api.github.com/user" 2>/dev/null) || true

    http_code=$(echo "$body" | tail -1)
    body=$(echo "$body" | sed '$d')

    if [[ "$http_code" == "200" ]]; then
        local username scopes
        # Extract login from JSON (portable — no grep -P)
        username=$(echo "$body" | sed -n 's/.*"login" *: *"\([^"]*\)".*/\1/p' | head -1)
        # Extract scopes header (portable — no sed i flag)
        scopes=$(grep -i "x-oauth-scopes:" "$tmpheaders" 2>/dev/null | sed 's/[Xx]-[Oo]auth-[Ss]copes: *//' | tr -d '\r' || echo "")
        rm -f "$tmpheaders"
        echo "valid|${username}|${scopes}"
    else
        rm -f "$tmpheaders"
        echo "invalid||"
    fi
}

# --- Offer to update token (deduplicates interactive/non-interactive prompt) ---
offer_update() {
    if [[ "$ACTION" == "check" && -t 0 ]]; then
        echo ""
        read -rp "  Would you like to update your token now? [Y/n] " ANSWER
        ANSWER="${ANSWER:-Y}"
        if [[ "$ANSWER" =~ ^[Yy] ]]; then
            ACTION="update"
        fi
    else
        echo ""
        echo -e "    ${_CHECK_ARROW} Update token: ${CYAN}$0 --update${RESET}"
    fi
}

# --- Setup flow (extracted to function for proper variable scoping) ---
do_setup() {
    echo ""
    echo -e "  ${DIM}$(printf '─%.0s' {1..44})${RESET}"
    echo ""
    echo -e "  ${BOLD}Git Profile Setup${RESET}"
    echo ""

    local input_name input_email input_gh_user
    local default_gh_user setup_token setup_result setup_status

    # Full name
    if [[ -n "$GIT_USER_NAME" ]]; then
        read -rp "  Full name [$GIT_USER_NAME]: " input_name
        input_name="${input_name:-$GIT_USER_NAME}"
    else
        read -rp "  Full name: " input_name
    fi
    if [[ -n "$input_name" ]]; then
        git config --global user.name "$input_name"
        echo -e "  ${_CHECK_PASS}  user.name = ${input_name}"
    fi

    # Email
    if [[ -n "$GIT_USER_EMAIL" ]]; then
        read -rp "  Email [$GIT_USER_EMAIL]: " input_email
        input_email="${input_email:-$GIT_USER_EMAIL}"
    else
        read -rp "  Email: " input_email
    fi
    if [[ -n "$input_email" ]]; then
        git config --global user.email "$input_email"
        echo -e "  ${_CHECK_PASS}  user.email = ${input_email}"
    fi

    # GitHub username — default from git config > stored credentials > token API
    default_gh_user="$GIT_GITHUB_USER"
    if [[ -z "$default_gh_user" ]]; then
        default_gh_user=$(get_stored_username)
    fi
    if [[ -z "$default_gh_user" ]]; then
        setup_token=$(get_stored_token)
        if [[ -n "$setup_token" ]]; then
            setup_result=$(get_github_api_details "$setup_token")
            setup_status=$(echo "$setup_result" | cut -d'|' -f1)
            if [[ "$setup_status" == "valid" ]]; then
                default_gh_user=$(echo "$setup_result" | cut -d'|' -f2)
            fi
        fi
    fi

    if [[ -n "$default_gh_user" ]]; then
        read -rp "  GitHub username [$default_gh_user]: " input_gh_user
        input_gh_user="${input_gh_user:-$default_gh_user}"
    else
        read -rp "  GitHub username: " input_gh_user
    fi
    if [[ -n "$input_gh_user" ]]; then
        git config --global github.user "$input_gh_user"
        echo -e "  ${_CHECK_PASS}  github.user = ${input_gh_user}"
    fi

    # Credential helper
    local cred
    cred=$(git config --get credential.helper 2>/dev/null || echo "")
    if [[ -z "$cred" ]]; then
        git config --global credential.helper store
        echo -e "  ${_CHECK_PASS}  credential.helper = store"
    fi

    echo ""
    echo -e "  ${GREEN}${BOLD}Profile configured${RESET}"

    # Refresh globals so subsequent checks use updated values
    GIT_USER_NAME=$(git config --global --get user.name 2>/dev/null || echo "")
    GIT_USER_EMAIL=$(git config --global --get user.email 2>/dev/null || echo "")
    GIT_GITHUB_USER=$(git config --global --get github.user 2>/dev/null || echo "")

    # Reset counters — initial profile failures were just resolved,
    # subsequent credential/validation checks start fresh
    TOTAL=0; PASSED=0; FAILED=0; WARNINGS=0
}

# --- Header ---
echo ""
echo -e "  ${BOLD}GitHub Token${RESET}  ${DIM}(${ENV})${RESET}"
echo -e "  ${DIM}$(printf '─%.0s' {1..44})${RESET}"
echo ""
echo -e "  ${_CHECK_ARROW} New token: ${CYAN}${TOKEN_URL}${RESET}"
echo ""

# ── 1. Git profile ───────────────────────────────────────────────
echo -e "  ${BOLD}Git Profile${RESET}"
echo ""

GIT_USER_NAME=$(git config --global --get user.name 2>/dev/null || echo "")
GIT_USER_EMAIL=$(git config --global --get user.email 2>/dev/null || echo "")
GIT_GITHUB_USER=$(git config --global --get github.user 2>/dev/null || echo "")

PROFILE_MISSING=false

if [[ -n "$GIT_USER_NAME" ]]; then
    check "Name" "pass" "$GIT_USER_NAME"
else
    check "Name" "fail" "not configured (git config --global user.name)"
    PROFILE_MISSING=true
fi

if [[ -n "$GIT_USER_EMAIL" ]]; then
    check "Email" "pass" "$GIT_USER_EMAIL"
else
    check "Email" "fail" "not configured (git config --global user.email)"
    PROFILE_MISSING=true
fi

if [[ -n "$GIT_GITHUB_USER" ]]; then
    check "GitHub username" "pass" "$GIT_GITHUB_USER"
else
    check "GitHub username" "warn" "not configured (git config --global github.user)"
    PROFILE_MISSING=true
fi

# Quick token probe — show status in the profile section before continuing
EARLY_TOKEN=$(get_stored_token)
EARLY_TOKEN_STATUS=""
if [[ -n "$EARLY_TOKEN" ]]; then
    EARLY_RESULT=$(get_github_api_details "$EARLY_TOKEN")
    EARLY_TOKEN_STATUS=$(echo "$EARLY_RESULT" | cut -d'|' -f1)
    if [[ "$EARLY_TOKEN_STATUS" == "valid" ]]; then
        check "Token" "pass" "valid ($(mask_token "$EARLY_TOKEN"))"
    else
        check "Token" "fail" "invalid or expired"
    fi
else
    check "Token" "fail" "not found"
fi

# Action menu — offer when there's something to fix
NEEDS_ATTENTION=false
if [[ "$PROFILE_MISSING" == true || "$EARLY_TOKEN_STATUS" != "valid" ]]; then
    NEEDS_ATTENTION=true
fi

if [[ "$NEEDS_ATTENTION" == true && "$ACTION" == "check" && -t 0 ]]; then
    echo ""
    echo -e "  ${BOLD}What would you like to do?${RESET}"
    echo -e "    ${CYAN}1${RESET}) Update token"
    echo -e "    ${CYAN}2${RESET}) Update user details"
    echo -e "    ${DIM}Enter${RESET}) Continue checks"
    echo ""
    read -rp "  > " MENU_CHOICE
    case "$MENU_CHOICE" in
        1) ACTION="update" ;;
        2) ACTION="setup" ;;
        *) ;; # continue with checks
    esac
fi

# ── Setup flow (runs early so profile is configured before token checks) ──
if [[ "$ACTION" == "setup" ]]; then
    do_setup
fi

# ── 2. Credential helper ─────────────────────────────────────────
echo ""
echo -e "  ${BOLD}Credential Helper${RESET}"
echo ""

CRED_HELPER=$(git config --get credential.helper 2>/dev/null || echo "")
if [[ -n "$CRED_HELPER" ]]; then
    check "Credential helper" "pass" "$CRED_HELPER"
else
    check "Credential helper" "fail" "not configured"
    echo ""
    echo -e "    ${_CHECK_ARROW} Set up: ${CYAN}git config --global credential.helper store${RESET}"
fi

# ── 3. Credentials ───────────────────────────────────────────────
echo ""
echo -e "  ${BOLD}Credentials${RESET}"
echo ""

# Query the active credential helper (what git actually uses)
_HELPER_OUTPUT=$(printf 'protocol=https\nhost=%s\n\n' "$GITHUB_HOST" \
    | GIT_TERMINAL_PROMPT=0 git credential fill 2>/dev/null || true)
HELPER_TOKEN=$(echo "$_HELPER_OUTPUT" | sed -n 's/^password=//p')
HELPER_USERNAME=$(echo "$_HELPER_OUTPUT" | sed -n 's/^username=//p')

# Also check ~/.git-credentials file directly
FILE_TOKEN=$(get_stored_token)
FILE_USERNAME=$(get_stored_username)

# Use what git actually uses (helper first), fall back to file
if [[ -n "$HELPER_TOKEN" ]]; then
    TOKEN="$HELPER_TOKEN"
    TOKEN_SOURCE="${CRED_HELPER:-credential helper}"
elif [[ -n "$FILE_TOKEN" ]]; then
    TOKEN="$FILE_TOKEN"
    TOKEN_SOURCE="$HOME/.git-credentials"
else
    TOKEN=""
    TOKEN_SOURCE=""
fi

USERNAME="${HELPER_USERNAME:-${FILE_USERNAME:-$(git config --get github.user 2>/dev/null || echo "")}}"

if [[ -n "$TOKEN" ]]; then
    check "GitHub token" "pass" "$(mask_token "$TOKEN") (via ${TOKEN_SOURCE})"
else
    check "GitHub token" "fail" "no token found for $GITHUB_HOST"
fi

if [[ -n "$USERNAME" ]]; then
    check "Username" "pass" "$USERNAME"
else
    check "Username" "warn" "will be detected from token"
fi

# Detect mismatch: file has a token but the active helper doesn't
if [[ -n "$FILE_TOKEN" && -z "$HELPER_TOKEN" && -n "$CRED_HELPER" && "$CRED_HELPER" != "store" ]]; then
    echo ""
    echo -e "    ${_CHECK_WARN}  ${YELLOW}Token in $HOME/.git-credentials but not in ${CRED_HELPER}${RESET}"
    echo -e "    ${DIM}Git uses ${CRED_HELPER} which doesn't have this token, so git operations will fail.${RESET}"
    if [[ "$ACTION" == "check" && -t 0 ]]; then
        echo ""
        read -rp "  Sync token to ${CRED_HELPER}? [Y/n] " ANSWER
        ANSWER="${ANSWER:-Y}"
        if [[ "$ANSWER" =~ ^[Yy] ]]; then
            _SYNC_USER="${FILE_USERNAME:-$(git config --get github.user 2>/dev/null || echo "")}"
            if [[ -n "$_SYNC_USER" && -n "$FILE_TOKEN" ]]; then
                printf 'protocol=https\nhost=%s\nusername=%s\npassword=%s\n\n' \
                    "$GITHUB_HOST" "$_SYNC_USER" "$FILE_TOKEN" | git credential approve 2>/dev/null
                echo -e "  ${_CHECK_PASS}  ${GREEN}Token synced to ${CRED_HELPER}${RESET}"
                HELPER_TOKEN="$FILE_TOKEN"
                HELPER_USERNAME="$_SYNC_USER"
                TOKEN="$FILE_TOKEN"
                TOKEN_SOURCE="$CRED_HELPER"
            else
                echo -e "  ${_CHECK_FAIL}  ${RED}Could not determine username — use $0 --update${RESET}"
            fi
        fi
    else
        echo -e "    ${_CHECK_ARROW} Fix: ${CYAN}$0 --update${RESET}"
    fi
fi

# ── 4. Token validation ──────────────────────────────────────────
echo ""
echo -e "  ${BOLD}Token Validation${RESET}"
echo ""

REMOTE_URL=$(git remote get-url origin 2>/dev/null || echo "")
TOKEN_STATUS=""
if [[ -n "$TOKEN" ]]; then
    API_RESULT=$(get_github_api_details "$TOKEN")
    TOKEN_STATUS=$(echo "$API_RESULT" | cut -d'|' -f1)
    API_USER=$(echo "$API_RESULT" | cut -d'|' -f2)
    API_SCOPES=$(echo "$API_RESULT" | cut -d'|' -f3)

    if [[ "$TOKEN_STATUS" == "valid" ]]; then
        check "API authentication" "pass" "token is valid"

        if [[ -n "$API_USER" ]]; then
            check "Authenticated as" "pass" "$API_USER"
            # Update USERNAME to the real GitHub login for use in update flow
            USERNAME="$API_USER"
        fi
        if [[ -n "$API_SCOPES" ]]; then
            check "Token scopes" "pass" "$API_SCOPES"
        else
            check "Token scopes" "warn" "none (fine-grained token or no scopes)"
        fi

        # Test repo access
        if [[ -n "$REMOTE_URL" ]]; then
            REPO=$(echo "$REMOTE_URL" | sed -n 's|.*github.com[:/]\(.*\)\.git|\1|p; s|.*github.com[:/]\(.*\)|\1|p')
            if [[ -n "$REPO" ]]; then
                REPO_CHECK=$(curl -s -o /dev/null -w "%{http_code}" \
                    -H "Authorization: token $TOKEN" \
                    -H "Accept: application/vnd.github+json" \
                    "https://api.github.com/repos/$REPO" 2>/dev/null) || true
                if [[ "$REPO_CHECK" == "200" ]]; then
                    check "Repo access ($REPO)" "pass" "accessible"
                else
                    check "Repo access ($REPO)" "fail" "HTTP $REPO_CHECK"
                fi
            fi
        fi
    else
        check "API authentication" "fail" "token is invalid or expired"
        offer_update
    fi
else
    check "API authentication" "fail" "no token to validate"
    offer_update
fi

# ── 5. Git remote test ───────────────────────────────────────────
echo ""
echo -e "  ${BOLD}Git Remote${RESET}"
echo ""

if [[ -n "$REMOTE_URL" ]]; then
    check "Remote URL" "pass" "$REMOTE_URL"

    # Only test ls-remote if we have a valid token (avoids interactive credential prompt)
    if [[ -n "$TOKEN" && "$TOKEN_STATUS" == "valid" ]]; then
        if git ls-remote --exit-code origin HEAD &>/dev/null; then
            check "Git authentication" "pass" "git ls-remote successful"
        else
            check "Git authentication" "fail" "git ls-remote failed"
        fi
    else
        check "Git authentication" "warn" "skipped (no valid token)"
    fi
else
    check "Remote URL" "fail" "no origin remote configured"
fi

# ── Update flow ──────────────────────────────────────────────────
if [[ "$ACTION" == "update" ]]; then
    echo ""
    echo -e "  ${DIM}$(printf '─%.0s' {1..44})${RESET}"
    echo ""
    echo -e "  ${BOLD}Update GitHub Token${RESET}"
    echo ""
    echo -e "  ${_CHECK_ARROW} Generate a new token at:"
    echo -e "    ${CYAN}${TOKEN_URL}${RESET}"
    echo ""

    # Prompt for token
    read -rsp "  GitHub token (input hidden): " NEW_TOKEN
    echo ""

    if [[ -z "$NEW_TOKEN" ]]; then
        echo -e "  ${RED}Token is required${RESET}"
        exit 1
    fi

    # Validate the new token and get the GitHub username from the API
    echo ""
    echo -e "  ${DIM}Validating new token...${RESET}"

    NEW_RESULT=$(get_github_api_details "$NEW_TOKEN")
    NEW_STATUS=$(echo "$NEW_RESULT" | cut -d'|' -f1)
    NEW_USER=$(echo "$NEW_RESULT" | cut -d'|' -f2)

    if [[ "$NEW_STATUS" != "valid" ]]; then
        echo -e "  ${_CHECK_FAIL}  ${RED}Token is invalid. Not saved.${RESET}"
        echo ""
        exit 1
    fi

    echo -e "  ${_CHECK_PASS}  ${GREEN}Token is valid (user: ${NEW_USER})${RESET}"

    # Save github.user if not already set
    EXISTING_GH_USER=$(git config --global --get github.user 2>/dev/null || echo "")
    if [[ -z "$EXISTING_GH_USER" && -n "$NEW_USER" ]]; then
        git config --global github.user "$NEW_USER"
        echo -e "  ${_CHECK_PASS}  ${GREEN}Saved github.user = ${NEW_USER}${RESET}"
    fi

    # Erase old credential from the active helper
    if [[ -n "${HELPER_TOKEN:-}" ]]; then
        printf 'protocol=https\nhost=%s\nusername=%s\npassword=%s\n\n' \
            "$GITHUB_HOST" "${HELPER_USERNAME:-${USERNAME:-}}" "$HELPER_TOKEN" \
            | git credential reject 2>/dev/null || true
    fi

    # Store new credential via the active credential helper (osxkeychain, store, etc.)
    printf 'protocol=https\nhost=%s\nusername=%s\npassword=%s\n\n' \
        "$GITHUB_HOST" "$NEW_USER" "$NEW_TOKEN" | git credential approve 2>/dev/null

    # Save to ~/.git-credentials as backup (create with secure permissions)
    if [[ -f "$CREDENTIALS_FILE" ]]; then
        sed_inplace "/$GITHUB_HOST/d" "$CREDENTIALS_FILE"
    else
        (umask 077 && touch "$CREDENTIALS_FILE")
    fi
    echo "https://${NEW_USER}:${NEW_TOKEN}@${GITHUB_HOST}" >> "$CREDENTIALS_FILE"
    chmod 600 "$CREDENTIALS_FILE"

    echo -e "  ${_CHECK_PASS}  ${GREEN}Credentials saved (${CRED_HELPER:-store} + $HOME/.git-credentials)${RESET}"

    # Verify git works
    echo ""
    if git ls-remote --exit-code origin HEAD &>/dev/null; then
        echo -e "  ${GREEN}${BOLD}Git authentication working!${RESET}"
    else
        echo -e "  ${YELLOW}Token saved but git ls-remote failed — check repo access permissions${RESET}"
    fi

    # Reset counters — update resolved earlier failures
    TOTAL=0; PASSED=0; FAILED=0; WARNINGS=0
fi

# ── Summary ──────────────────────────────────────────────────────
echo ""
echo -e "  ${DIM}$(printf '─%.0s' {1..44})${RESET}"
echo ""

if [[ "$ACTION" == "update" ]]; then
    echo -e "  ${GREEN}${BOLD}Token updated successfully${RESET}"
elif [[ "$ACTION" == "setup" ]]; then
    echo -e "  ${GREEN}${BOLD}Profile configured${RESET}"
elif [[ $FAILED -eq 0 && $WARNINGS -eq 0 ]]; then
    echo -e "  ${GREEN}${BOLD}All ${TOTAL} checks passed${RESET} - GitHub token is working"
elif [[ $FAILED -eq 0 ]]; then
    echo -e "  ${GREEN}${BOLD}${PASSED}/${TOTAL} passed${RESET}  ${YELLOW}${WARNINGS} warning(s)${RESET}"
else
    echo -e "  ${RED}${BOLD}${FAILED} failed${RESET}  ${GREEN}${PASSED} passed${RESET}  ${YELLOW}${WARNINGS} warning(s)${RESET}"
fi

# ── Action menu (always shown in interactive check mode) ─────────
if [[ "$ACTION" == "check" && -t 0 ]]; then
    echo ""
    echo -e "  ${CYAN}1${RESET}) Update token  ${CYAN}2${RESET}) Update user details  ${DIM}Enter${RESET}) Done"
    read -rp "  > " END_CHOICE
    case "$END_CHOICE" in
        1)
            # Re-run in update mode
            exec "$0" --update
            ;;
        2)
            # Re-run in setup mode
            exec "$0" --setup
            ;;
        *) ;; # exit normally
    esac
fi

echo ""
