#!/usr/bin/env bash
# Shared helpers for AWS scripts. Source this file; do not execute it directly.
#
# Scripts that source this file (aws-costs.sh, aws-rightsizing.sh, aws-security.sh)
# are NOT standalone templates. If copying them to another project, also copy this
# file and preserve the relative path, or inline the helpers you need.

set -euo pipefail

if [[ -n "${_AWS_COMMON_LOADED:-}" ]]; then
    if [[ "${BASH_SOURCE[0]}" != "$0" ]]; then
        return 0
    fi
    exit 0
fi
_AWS_COMMON_LOADED=1

# shellcheck disable=SC2034
RED='\033[0;31m'
# shellcheck disable=SC2034
GREEN='\033[0;32m'
# shellcheck disable=SC2034
YELLOW='\033[1;33m'
# shellcheck disable=SC2034
BLUE='\033[0;34m'
# shellcheck disable=SC2034
CYAN='\033[0;36m'
BOLD='\033[1m'
# shellcheck disable=SC2034
DIM='\033[2m'
NC='\033[0m'

AWS_COMMON_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(
    git -C "$AWS_COMMON_DIR" rev-parse --show-toplevel 2>/dev/null \
        || (cd "$AWS_COMMON_DIR/../.." && pwd)
)"
ENV_FILE="$PROJECT_ROOT/.env"

trim_leading_whitespace() {
    local value="$1"
    printf '%s' "${value#"${value%%[![:space:]]*}"}"
}

trim_trailing_whitespace() {
    local value="$1"
    printf '%s' "${value%"${value##*[![:space:]]}"}"
}

load_env_file() {
    local line key value

    [[ -f "$ENV_FILE" ]] || return 0

    while IFS= read -r line || [[ -n "$line" ]]; do
        [[ "$line" =~ ^[[:space:]]*# ]] && continue
        [[ "$line" =~ ^[[:space:]]*$ ]] && continue

        if [[ "$line" =~ ^[[:space:]]*(export[[:space:]]+)?([A-Za-z_][A-Za-z_0-9]*)[[:space:]]*=(.*)$ ]]; then
            key="${BASH_REMATCH[2]}"
            value="${BASH_REMATCH[3]}"
            value="$(trim_leading_whitespace "$value")"
            value="$(trim_trailing_whitespace "$value")"

            if [[ "$value" =~ ^\"(.*)\"$ ]]; then
                value="${BASH_REMATCH[1]}"
            elif [[ "$value" =~ ^\'(.*)\'$ ]]; then
                value="${BASH_REMATCH[1]}"
            fi

            declare -gx "$key=$value"
        fi
    done < "$ENV_FILE"
}

load_env_file

AWS_PROFILE_NAME="${AWS_PROFILE_NAME:-default}"
AWS_REGION="${AWS_REGION:-${AWS_DEFAULT_REGION:-us-east-1}}"

if [[ -n "${AWS_ACCESS_KEY_ID:-}" && -n "${AWS_SECRET_ACCESS_KEY:-}" ]]; then
    export AWS_ACCESS_KEY_ID
    export AWS_SECRET_ACCESS_KEY
    export AWS_DEFAULT_REGION="${AWS_DEFAULT_REGION:-$AWS_REGION}"

    if [[ -n "${AWS_SESSION_TOKEN:-}" ]]; then
        # Preserve session token from .env or pre-existing environment (e.g. assume-role)
        export AWS_SESSION_TOKEN
    else
        unset AWS_SESSION_TOKEN 2>/dev/null || true
    fi

    unset AWS_PROFILE 2>/dev/null || true
    AWS_AUTH_MODE="access keys from .env"
else
    export AWS_PROFILE="${AWS_PROFILE:-$AWS_PROFILE_NAME}"
    export AWS_DEFAULT_REGION="${AWS_DEFAULT_REGION:-$AWS_REGION}"
    AWS_AUTH_MODE="profile (${AWS_PROFILE})"
fi

require_cmd() {
    if ! command -v "$1" >/dev/null 2>&1; then
        echo -e "${RED}Error: $1 is not installed${NC}"
        if [[ -n "${2:-}" ]]; then
            echo "$2"
        fi
        exit 1
    fi
}

require_modern_bash() {
    if (( BASH_VERSINFO[0] < 4 )); then
        echo -e "${RED}Error: this script requires Bash 4+${NC}"
        echo "Install a newer bash and ensure it is first on PATH."
        exit 1
    fi
}

require_unix() {
    case "$(uname -s)" in
        MINGW*|MSYS*)
            echo -e "${RED}This script requires WSL, Linux, or macOS${NC}"
            echo -e "Run it inside WSL: ${BOLD}wsl bash $0${NC}"
            exit 1
            ;;
    esac
}

ensure_aws_cli() {
    require_cmd aws "Install AWS CLI v2: https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html"
}

show_aws_auth_help() {
    echo "To fix this, either:"
    echo "  1. Put AWS_ACCESS_KEY_ID and AWS_SECRET_ACCESS_KEY in .env"
    echo "  2. Run: aws sso login --profile ${AWS_PROFILE:-$AWS_PROFILE_NAME}"
}

require_aws_auth() {
    if ! aws sts get-caller-identity >/dev/null 2>&1; then
        echo -e "${RED}Error: AWS credentials are not valid (${AWS_AUTH_MODE})${NC}"
        echo ""
        show_aws_auth_help
        exit 1
    fi
}
