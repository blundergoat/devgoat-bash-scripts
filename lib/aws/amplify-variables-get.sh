#!/usr/bin/env bash
#
# amplify-variables-get.sh - View Amplify environment variables
#
# USAGE:
#   ./scripts/amplify-variables-get.sh              # Show all variables
#   ./scripts/amplify-variables-get.sh VAR_NAME     # Show specific variable
#   ./scripts/amplify-variables-get.sh --json       # Output as JSON
#
# EXAMPLES:
#   ./scripts/amplify-variables-get.sh
#   ./scripts/amplify-variables-get.sh NEXT_PUBLIC_GOOGLE_CLIENT_ID
#   ./scripts/amplify-variables-get.sh API_URL
#
# NOTE:
#   NEXT_PUBLIC_* variables are baked into the frontend at BUILD TIME.
#   Changes require a rebuild to take effect.
#
# RELATED:
#   - ./scripts/amplify-variables-set.sh  - Update env vars
#   - ./scripts/amplify-health-check.sh   - Check app health
#

set -euo pipefail

# ---- CONFIGURATION ----
# Customize these variables for your project, or set them as environment variables.
AMPLIFY_APP_ID="${AMPLIFY_APP_ID:-your-amplify-app-id}"
# ---- END CONFIGURATION ----

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
AWS_CLI="${SCRIPT_DIR}/aws-cli.sh"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Parse arguments
OUTPUT_JSON=false
VAR_NAME=""

while [[ $# -gt 0 ]]; do
    case "$1" in
        --json)
            OUTPUT_JSON=true
            shift
            ;;
        --help|-h)
            echo "Usage: $(basename "$0") [OPTIONS] [VAR_NAME]"
            echo ""
            echo "View Amplify environment variables."
            echo ""
            echo "Options:"
            echo "  --json      Output as JSON"
            echo "  --help      Show this help"
            echo ""
            echo "Arguments:"
            echo "  VAR_NAME    Optional: Show only this variable"
            echo ""
            echo "Examples:"
            echo "  $(basename "$0")                              # Show all variables"
            echo "  $(basename "$0") NEXT_PUBLIC_GOOGLE_CLIENT_ID # Show specific variable"
            echo "  $(basename "$0") --json                       # Output as JSON"
            exit 0
            ;;
        -*)
            echo "Unknown option: $1" >&2
            exit 1
            ;;
        *)
            VAR_NAME="$1"
            shift
            ;;
    esac
done

# Check if aws-cli.sh exists
if [[ ! -x "${AWS_CLI}" ]]; then
    echo -e "${RED}[ERROR]${NC} AWS CLI wrapper not found: ${AWS_CLI}" >&2
    exit 1
fi

# Get app info
APP_INFO=$("${AWS_CLI}" amplify get-app --app-id "${AMPLIFY_APP_ID}" 2>&1) || {
    echo -e "${RED}[ERROR]${NC} Failed to get app info" >&2
    echo "${APP_INFO}" >&2
    exit 1
}

# Extract environment variables
ENV_VARS=$(echo "${APP_INFO}" | jq '.app.environmentVariables // {}')

# If JSON output requested
if [[ "${OUTPUT_JSON}" == "true" ]]; then
    if [[ -n "${VAR_NAME}" ]]; then
        echo "${ENV_VARS}" | jq -r --arg name "${VAR_NAME}" '.[$name] // empty'
    else
        echo "${ENV_VARS}" | jq .
    fi
    exit 0
fi

# If specific variable requested
if [[ -n "${VAR_NAME}" ]]; then
    VALUE=$(echo "${ENV_VARS}" | jq -r --arg name "${VAR_NAME}" '.[$name] // empty')
    if [[ -z "${VALUE}" ]]; then
        echo -e "${YELLOW}[WARN]${NC} Variable '${VAR_NAME}' is not set" >&2
        exit 1
    else
        echo "${VALUE}"
    fi
    exit 0
fi

# Show all variables with formatting
APP_NAME=$(echo "${APP_INFO}" | jq -r '.app.name')
echo -e "${BLUE}Amplify Environment Variables${NC}"
echo -e "App: ${CYAN}${APP_NAME}${NC} (${AMPLIFY_APP_ID})"
echo ""

VAR_COUNT=$(echo "${ENV_VARS}" | jq 'length')

if [[ "${VAR_COUNT}" -eq 0 ]]; then
    echo -e "${YELLOW}No environment variables configured${NC}"
    exit 0
fi

# Group variables by type
echo -e "${GREEN}Public Variables (NEXT_PUBLIC_*):${NC}"
echo -e "${YELLOW}These are baked into the frontend at build time${NC}"
echo ""

echo "${ENV_VARS}" | jq -r 'to_entries | .[] | select(.key | startswith("NEXT_PUBLIC_")) | "\(.key)=\(.value)"' | while read -r line; do
    KEY=$(echo "${line}" | cut -d'=' -f1)
    VALUE=$(echo "${line}" | cut -d'=' -f2-)
    # Truncate long values
    if [[ ${#VALUE} -gt 60 ]]; then
        VALUE="${VALUE:0:57}..."
    fi
    echo -e "  ${CYAN}${KEY}${NC}=${VALUE}"
done

echo ""
echo -e "${GREEN}Server Variables:${NC}"
echo -e "${YELLOW}These are available at runtime on the server${NC}"
echo ""

echo "${ENV_VARS}" | jq -r 'to_entries | .[] | select(.key | startswith("NEXT_PUBLIC_") | not) | "\(.key)=\(.value)"' | while read -r line; do
    KEY=$(echo "${line}" | cut -d'=' -f1)
    VALUE=$(echo "${line}" | cut -d'=' -f2-)
    # Truncate long values
    if [[ ${#VALUE} -gt 60 ]]; then
        VALUE="${VALUE:0:57}..."
    fi
    echo -e "  ${CYAN}${KEY}${NC}=${VALUE}"
done

echo ""
echo -e "${BLUE}Total: ${VAR_COUNT} variables${NC}"
echo ""
echo -e "To update variables: ${CYAN}./scripts/amplify-variables-set.sh --help${NC}"
