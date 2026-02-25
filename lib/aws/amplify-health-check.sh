#!/usr/bin/env bash
#
# amplify-health-check.sh - Check health status of AWS Amplify app
#
# USAGE:
#   ./scripts/amplify-health-check.sh
#
# WHAT IT CHECKS:
#   - App exists and is accessible
#   - Current branch configuration
#   - Recent build jobs and their status
#   - Environment variables (names only, not values)
#
# PREREQUISITES:
#   - AWS CLI configured with correct profile
#   - ./scripts/aws-cli.sh wrapper available
#
# RELATED:
#   - ./scripts/amplify-variables-get.sh  - View env var values
#   - ./scripts/amplify-variables-set.sh  - Update env vars
#

set -euo pipefail

# ---- CONFIGURATION ----
# Customize these variables for your project, or set them as environment variables.
AMPLIFY_APP_ID="${AMPLIFY_APP_ID:-your-amplify-app-id}"
AMPLIFY_BRANCH="${AMPLIFY_BRANCH:-main}"

# Required environment variables to check (space-separated)
REQUIRED_PUBLIC_VARS="${REQUIRED_PUBLIC_VARS:-NEXT_PUBLIC_API_URL}"
REQUIRED_SERVER_VARS="${REQUIRED_SERVER_VARS:-API_URL}"
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
NC='\033[0m' # No Color

# Helper functions
info() { echo -e "${BLUE}[INFO]${NC} $*"; }
success() { echo -e "${GREEN}[OK]${NC} $*"; }
warn() { echo -e "${YELLOW}[WARN]${NC} $*"; }
error() { echo -e "${RED}[ERROR]${NC} $*"; }
header() { echo -e "\n${BLUE}=== $* ===${NC}"; }

# Check if aws-cli.sh exists
if [[ ! -x "${AWS_CLI}" ]]; then
    error "AWS CLI wrapper not found: ${AWS_CLI}"
    exit 1
fi

echo ""
echo -e "${BLUE}==========================================${NC}"
echo -e "${BLUE}  Amplify Health Check${NC}"
echo -e "${BLUE}==========================================${NC}"
echo ""

header "App Information"
info "App ID: ${AMPLIFY_APP_ID}"
info "Branch: ${BRANCH}"

# Get app details
header "Fetching App Details"
APP_INFO=$("${AWS_CLI}" amplify get-app --app-id "${AMPLIFY_APP_ID}" 2>&1) || {
    error "Failed to get app info. Is the app ID correct?"
    echo "${APP_INFO}"
    exit 1
}

APP_NAME=$(echo "${APP_INFO}" | jq -r '.app.name')
APP_REPO=$(echo "${APP_INFO}" | jq -r '.app.repository // "N/A"')
APP_PLATFORM=$(echo "${APP_INFO}" | jq -r '.app.platform')
APP_CREATE_TIME=$(echo "${APP_INFO}" | jq -r '.app.createTime')

success "App found: ${APP_NAME}"
info "  Repository: ${APP_REPO}"
info "  Platform: ${APP_PLATFORM}"
info "  Created: ${APP_CREATE_TIME}"

# Check environment variables (names only)
header "Environment Variables"
ENV_VARS=$(echo "${APP_INFO}" | jq -r '.app.environmentVariables // {} | keys[]' 2>/dev/null || echo "")

if [[ -z "${ENV_VARS}" ]]; then
    warn "No environment variables configured"
else
    echo "Configured variables:"
    echo "${ENV_VARS}" | while read -r var; do
        if [[ "${var}" == NEXT_PUBLIC_* ]]; then
            echo -e "  ${GREEN}${var}${NC} (public)"
        else
            echo -e "  ${YELLOW}${var}${NC} (server-only)"
        fi
    done
fi

# Check for required variables
header "Required Variables Check"

# Build arrays from space-separated config
read -ra REQ_PUBLIC_ARR <<< "${REQUIRED_PUBLIC_VARS}"
read -ra REQ_SERVER_ARR <<< "${REQUIRED_SERVER_VARS}"

for var in "${REQ_PUBLIC_ARR[@]}"; do
    if echo "${ENV_VARS}" | grep -q "^${var}$"; then
        success "${var} is configured"
    else
        warn "${var} is NOT configured"
    fi
done

for var in "${REQ_SERVER_ARR[@]}"; do
    if echo "${ENV_VARS}" | grep -q "^${var}$"; then
        success "${var} is configured"
    else
        warn "${var} is NOT configured"
    fi
done

# Get branch info
header "Branch Configuration"
BRANCH_INFO=$("${AWS_CLI}" amplify get-branch \
    --app-id "${AMPLIFY_APP_ID}" \
    --branch-name "${BRANCH}" 2>&1) || {
    warn "Branch '${BRANCH}' not found"
    BRANCH_INFO=""
}

if [[ -n "${BRANCH_INFO}" ]]; then
    BRANCH_STATUS=$(echo "${BRANCH_INFO}" | jq -r '.branch.activeJobId // "none"')
    BRANCH_STAGE=$(echo "${BRANCH_INFO}" | jq -r '.branch.stage')
    BRANCH_UPDATED=$(echo "${BRANCH_INFO}" | jq -r '.branch.updateTime')

    success "Branch '${BRANCH}' exists"
    info "  Stage: ${BRANCH_STAGE}"
    info "  Last updated: ${BRANCH_UPDATED}"
    if [[ "${BRANCH_STATUS}" != "none" && "${BRANCH_STATUS}" != "null" ]]; then
        warn "  Active job: ${BRANCH_STATUS}"
    fi
fi

# Get recent jobs
header "Recent Build Jobs (last 5)"
JOBS=$("${AWS_CLI}" amplify list-jobs \
    --app-id "${AMPLIFY_APP_ID}" \
    --branch-name "${BRANCH}" \
    --max-results 5 2>&1) || {
    warn "Failed to list jobs"
    JOBS=""
}

if [[ -n "${JOBS}" ]]; then
    JOB_COUNT=$(echo "${JOBS}" | jq '.jobSummaries | length')

    if [[ "${JOB_COUNT}" -eq 0 ]]; then
        info "No build jobs found"
    else
        echo "${JOBS}" | jq -r '.jobSummaries[] | "\(.jobId) | \(.status) | \(.commitId[:7] // "N/A") | \(.endTime // .startTime)"' | while read -r line; do
            JOB_ID=$(echo "${line}" | cut -d'|' -f1 | xargs)
            STATUS=$(echo "${line}" | cut -d'|' -f2 | xargs)
            COMMIT=$(echo "${line}" | cut -d'|' -f3 | xargs)
            TIME=$(echo "${line}" | cut -d'|' -f4 | xargs)

            case "${STATUS}" in
                SUCCEED)
                    echo -e "  ${GREEN}${STATUS}${NC} | Job ${JOB_ID} | Commit ${COMMIT} | ${TIME}"
                    ;;
                FAILED|CANCELLED)
                    echo -e "  ${RED}${STATUS}${NC} | Job ${JOB_ID} | Commit ${COMMIT} | ${TIME}"
                    ;;
                RUNNING|PENDING)
                    echo -e "  ${YELLOW}${STATUS}${NC} | Job ${JOB_ID} | Commit ${COMMIT} | ${TIME}"
                    ;;
                *)
                    echo -e "  ${STATUS} | Job ${JOB_ID} | Commit ${COMMIT} | ${TIME}"
                    ;;
            esac
        done
    fi
fi

# Summary
header "Summary"
LATEST_STATUS=$(echo "${JOBS}" | jq -r '.jobSummaries[0].status // "UNKNOWN"' 2>/dev/null || echo "UNKNOWN")

case "${LATEST_STATUS}" in
    SUCCEED)
        success "Latest build: ${GREEN}SUCCEEDED${NC}"
        ;;
    FAILED)
        error "Latest build: ${RED}FAILED${NC}"
        info "Run: ./scripts/aws-cli.sh amplify get-job --app-id ${AMPLIFY_APP_ID} --branch-name ${BRANCH} --job-id <job-id>"
        ;;
    RUNNING|PENDING)
        warn "Latest build: ${YELLOW}${LATEST_STATUS}${NC}"
        ;;
    *)
        info "Latest build status: ${LATEST_STATUS}"
        ;;
esac

echo ""
info "For more details:"
info "  View env vars: ./scripts/amplify-variables-get.sh"
info "  Set env vars:  ./scripts/amplify-variables-set.sh --help"
info "  Trigger build: ./scripts/aws-cli.sh amplify start-job --app-id ${AMPLIFY_APP_ID} --branch-name ${BRANCH} --job-type RELEASE"
