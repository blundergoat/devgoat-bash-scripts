#!/usr/bin/env bash
#
# amplify-variables-set.sh - Set Amplify environment variables
#
# USAGE:
#   ./scripts/amplify-variables-set.sh KEY=VALUE [KEY=VALUE...]
#   ./scripts/amplify-variables-set.sh --rebuild KEY=VALUE
#   ./scripts/amplify-variables-set.sh --file env.json
#
# EXAMPLES:
#   # Set a single variable
#   ./scripts/amplify-variables-set.sh NEXT_PUBLIC_GOOGLE_CLIENT_ID=xxx.apps.googleusercontent.com
#
#   # Set multiple variables
#   ./scripts/amplify-variables-set.sh API_URL=https://api.example.com NEXT_PUBLIC_API_URL=https://api.example.com
#
#   # Set and trigger rebuild (required for NEXT_PUBLIC_* changes)
#   ./scripts/amplify-variables-set.sh --rebuild NEXT_PUBLIC_GOOGLE_CLIENT_ID=xxx.apps.googleusercontent.com
#
#   # Load from JSON file
#   ./scripts/amplify-variables-set.sh --file ./env-vars.json
#
# IMPORTANT:
#   NEXT_PUBLIC_* variables are baked into the frontend at BUILD TIME.
#   Use --rebuild flag to trigger a rebuild after changing them.
#
# RELATED:
#   - ./scripts/amplify-variables-get.sh  - View current vars
#   - ./scripts/amplify-health-check.sh   - Check app health
#

set -euo pipefail

# ---- CONFIGURATION ----
# Customize these variables for your project, or set them as environment variables.
AMPLIFY_APP_ID="${AMPLIFY_APP_ID:-your-amplify-app-id}"
AMPLIFY_BRANCH="${AMPLIFY_BRANCH:-main}"
# ---- END CONFIGURATION ----

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
AWS_CLI="${SCRIPT_DIR}/aws-cli.sh"
BRANCH="${AMPLIFY_BRANCH}"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Helper functions
info() { echo -e "${BLUE}[INFO]${NC} $*"; }
success() { echo -e "${GREEN}[OK]${NC} $*"; }
warn() { echo -e "${YELLOW}[WARN]${NC} $*"; }
error() { echo -e "${RED}[ERROR]${NC} $*" >&2; }

show_help() {
    cat << EOF
Usage: $(basename "$0") [OPTIONS] KEY=VALUE [KEY=VALUE...]

Set Amplify environment variables.

Options:
  --rebuild     Trigger a rebuild after setting variables
  --file FILE   Load variables from a JSON file
  --yes, -y     Skip confirmation prompt
  --help        Show this help

Arguments:
  KEY=VALUE     Environment variable to set (can specify multiple)

Examples:
  # Set a single variable
  $(basename "$0") API_URL=https://api.example.com

  # Set multiple variables
  $(basename "$0") API_URL=https://api.example.com NEXT_PUBLIC_API_URL=https://api.example.com

  # Set and trigger rebuild
  $(basename "$0") --rebuild NEXT_PUBLIC_GOOGLE_CLIENT_ID=xxx.apps.googleusercontent.com

  # Load from JSON file (format: {"KEY": "value", ...})
  $(basename "$0") --file ./env-vars.json

IMPORTANT:
  NEXT_PUBLIC_* variables are baked into the frontend at BUILD TIME.
  Changes require a rebuild to take effect. Use --rebuild flag.
EOF
}

# Parse arguments
TRIGGER_REBUILD=false
SKIP_CONFIRM=false
JSON_FILE=""
declare -a NEW_VARS=()

while [[ $# -gt 0 ]]; do
    case "$1" in
        --rebuild)
            TRIGGER_REBUILD=true
            shift
            ;;
        --file)
            JSON_FILE="$2"
            shift 2
            ;;
        --yes|-y)
            SKIP_CONFIRM=true
            shift
            ;;
        --help|-h)
            show_help
            exit 0
            ;;
        -*)
            error "Unknown option: $1"
            exit 1
            ;;
        *=*)
            NEW_VARS+=("$1")
            shift
            ;;
        *)
            error "Invalid argument: $1 (expected KEY=VALUE format)"
            exit 1
            ;;
    esac
done

# Check if aws-cli.sh exists
if [[ ! -x "${AWS_CLI}" ]]; then
    error "AWS CLI wrapper not found: ${AWS_CLI}"
    exit 1
fi

# Validate input
if [[ ${#NEW_VARS[@]} -eq 0 && -z "${JSON_FILE}" ]]; then
    error "No variables specified"
    echo "Usage: $(basename "$0") KEY=VALUE [KEY=VALUE...]"
    echo "       $(basename "$0") --file env.json"
    exit 1
fi

# Get current app info
info "Fetching current configuration..."
APP_INFO=$("${AWS_CLI}" amplify get-app --app-id "${AMPLIFY_APP_ID}" 2>&1) || {
    error "Failed to get app info"
    echo "${APP_INFO}" >&2
    exit 1
}

APP_NAME=$(echo "${APP_INFO}" | jq -r '.app.name')
CURRENT_VARS=$(echo "${APP_INFO}" | jq '.app.environmentVariables // {}')

info "App: ${APP_NAME} (${AMPLIFY_APP_ID})"

# Build the new environment variables object
# Start with current vars
MERGED_VARS="${CURRENT_VARS}"

# If loading from file
if [[ -n "${JSON_FILE}" ]]; then
    if [[ ! -f "${JSON_FILE}" ]]; then
        error "File not found: ${JSON_FILE}"
        exit 1
    fi

    FILE_VARS=$(cat "${JSON_FILE}")
    if ! echo "${FILE_VARS}" | jq . > /dev/null 2>&1; then
        error "Invalid JSON in file: ${JSON_FILE}"
        exit 1
    fi

    # Merge file vars
    MERGED_VARS=$(echo "${MERGED_VARS}" | jq --argjson new "${FILE_VARS}" '. + $new')
    info "Loaded variables from ${JSON_FILE}"
fi

# Add command-line vars
HAS_PUBLIC_VARS=false
for var in "${NEW_VARS[@]}"; do
    KEY="${var%%=*}"
    VALUE="${var#*=}"

    if [[ "${KEY}" == NEXT_PUBLIC_* ]]; then
        HAS_PUBLIC_VARS=true
    fi

    MERGED_VARS=$(echo "${MERGED_VARS}" | jq --arg key "${KEY}" --arg val "${VALUE}" '. + {($key): $val}')
done

# Show what will change
echo ""
echo -e "${CYAN}Variables to be set:${NC}"
echo ""

# Show new/changed variables
for var in "${NEW_VARS[@]}"; do
    KEY="${var%%=*}"
    VALUE="${var#*=}"
    OLD_VALUE=$(echo "${CURRENT_VARS}" | jq -r --arg key "${KEY}" '.[$key] // empty')

    if [[ -z "${OLD_VALUE}" ]]; then
        echo -e "  ${GREEN}+ ${KEY}${NC}=${VALUE} (new)"
    elif [[ "${OLD_VALUE}" != "${VALUE}" ]]; then
        echo -e "  ${YELLOW}~ ${KEY}${NC}=${VALUE} (was: ${OLD_VALUE})"
    else
        echo -e "  ${BLUE}= ${KEY}${NC}=${VALUE} (unchanged)"
    fi
done

if [[ -n "${JSON_FILE}" ]]; then
    echo -e "  ${CYAN}(plus variables from ${JSON_FILE})${NC}"
fi

echo ""

# Warn about NEXT_PUBLIC_* changes
if [[ "${HAS_PUBLIC_VARS}" == "true" && "${TRIGGER_REBUILD}" == "false" ]]; then
    warn "You are setting NEXT_PUBLIC_* variables without --rebuild"
    warn "These changes will NOT take effect until a rebuild is triggered!"
    echo ""
fi

# Confirm
if [[ "${SKIP_CONFIRM}" == "false" ]]; then
    echo -e "${YELLOW}This will update the Amplify environment variables.${NC}"
    if [[ "${TRIGGER_REBUILD}" == "true" ]]; then
        echo -e "${YELLOW}A rebuild will be triggered after updating.${NC}"
    fi
    read -p "Continue? [y/N] " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        info "Cancelled"
        exit 0
    fi
fi

# Update the app
info "Updating environment variables..."

UPDATE_RESULT=$("${AWS_CLI}" amplify update-app \
    --app-id "${AMPLIFY_APP_ID}" \
    --environment-variables "${MERGED_VARS}" 2>&1) || {
    error "Failed to update environment variables"
    echo "${UPDATE_RESULT}" >&2
    exit 1
}

success "Environment variables updated"

# Trigger rebuild if requested
if [[ "${TRIGGER_REBUILD}" == "true" ]]; then
    info "Triggering rebuild..."

    JOB_RESULT=$("${AWS_CLI}" amplify start-job \
        --app-id "${AMPLIFY_APP_ID}" \
        --branch-name "${BRANCH}" \
        --job-type RELEASE 2>&1) || {
        error "Failed to start rebuild"
        echo "${JOB_RESULT}" >&2
        exit 1
    }

    JOB_ID=$(echo "${JOB_RESULT}" | jq -r '.jobSummary.jobId')
    success "Rebuild started: Job ${JOB_ID}"

    echo ""
    info "Monitor build progress:"
    info "  ./scripts/aws-cli.sh amplify get-job --app-id ${AMPLIFY_APP_ID} --branch-name ${BRANCH} --job-id ${JOB_ID}"
    info "  ./scripts/amplify-health-check.sh"
else
    if [[ "${HAS_PUBLIC_VARS}" == "true" ]]; then
        echo ""
        warn "Remember: NEXT_PUBLIC_* changes require a rebuild!"
        info "Trigger manually: ./scripts/aws-cli.sh amplify start-job --app-id ${AMPLIFY_APP_ID} --branch-name ${BRANCH} --job-type RELEASE"
    fi
fi

echo ""
success "Done!"
