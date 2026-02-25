#!/usr/bin/env bash
#
# secrets-manager-health-check.sh - Check health of AWS Secrets Manager secrets
#
# USAGE:
#   ./scripts/secrets-manager-health-check.sh
#
# WHAT IT CHECKS:
#   - Required secrets exist
#   - Secrets are accessible (not pending deletion)
#   - Secret values are not empty
#   - Last rotation dates (if applicable)
#
# PREREQUISITES:
#   - AWS CLI configured with correct profile
#   - ./scripts/aws-cli.sh wrapper available
#
# RELATED:
#   - ./scripts/secrets-manager-get.sh  - View secret values
#   - ./scripts/secrets-manager-set.sh  - Create/update secrets
#

set -euo pipefail

# ---- CONFIGURATION ----
# Customize these variables for your project, or set them as environment variables.
SECRETS_PREFIX="${SECRETS_PREFIX:-/my-project/prod}"

# Required secrets (space-separated suffixes appended to SECRETS_PREFIX)
# Example: "admin/api-key jwt/signing-key db/url"
REQUIRED_SECRET_SUFFIXES="${REQUIRED_SECRET_SUFFIXES:-admin/api-key jwt/signing-key db/url}"

# Optional secrets (space-separated suffixes appended to SECRETS_PREFIX)
# Example: "recaptcha/secret-key session/hash-salt"
OPTIONAL_SECRET_SUFFIXES="${OPTIONAL_SECRET_SUFFIXES:-}"
# ---- END CONFIGURATION ----

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
AWS_CLI="${SCRIPT_DIR}/aws-cli.sh"

# Secret paths
SECRET_PREFIX="${SECRETS_PREFIX}"

# Build arrays from space-separated config
REQUIRED_SECRETS=()
for suffix in ${REQUIRED_SECRET_SUFFIXES}; do
    REQUIRED_SECRETS+=("${SECRET_PREFIX}/${suffix}")
done

OPTIONAL_SECRETS=()
for suffix in ${OPTIONAL_SECRET_SUFFIXES}; do
    OPTIONAL_SECRETS+=("${SECRET_PREFIX}/${suffix}")
done

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
echo -e "${BLUE}  Secrets Manager Health Check${NC}"
echo -e "${BLUE}==========================================${NC}"
echo ""

header "Configuration"
info "Secret prefix: ${SECRET_PREFIX}"
info "Region: ${AWS_REGION:-us-east-1}"

# Function to check a single secret
check_secret() {
    local secret_id="$1"
    local required="$2"
    local secret_name="${secret_id##*/}"

    # Try to describe the secret
    DESCRIBE_RESULT=$("${AWS_CLI}" secretsmanager describe-secret \
        --secret-id "${secret_id}" 2>&1) || {
        if [[ "${required}" == "true" ]]; then
            error "${secret_name}: NOT FOUND (required)"
            return 1
        else
            warn "${secret_name}: not configured (optional)"
            return 0
        fi
    }

    # Check if marked for deletion
    DELETED_DATE=$(echo "${DESCRIBE_RESULT}" | jq -r '.DeletedDate // empty')
    if [[ -n "${DELETED_DATE}" ]]; then
        if [[ "${required}" == "true" ]]; then
            error "${secret_name}: PENDING DELETION (${DELETED_DATE})"
            return 1
        else
            warn "${secret_name}: pending deletion (optional)"
            return 0
        fi
    fi

    # Try to get the value to verify it's not empty
    GET_RESULT=$("${AWS_CLI}" secretsmanager get-secret-value \
        --secret-id "${secret_id}" \
        --query 'SecretString' \
        --output text 2>&1) || {
        if [[ "${required}" == "true" ]]; then
            error "${secret_name}: CANNOT READ VALUE"
            return 1
        else
            warn "${secret_name}: cannot read value (optional)"
            return 0
        fi
    }

    # Check if empty
    if [[ -z "${GET_RESULT}" || "${GET_RESULT}" == "null" ]]; then
        if [[ "${required}" == "true" ]]; then
            error "${secret_name}: EMPTY VALUE"
            return 1
        else
            warn "${secret_name}: empty value (optional)"
            return 0
        fi
    fi

    # Get metadata
    MODIFIED=$(echo "${DESCRIBE_RESULT}" | jq -r '.LastChangedDate // "N/A"')
    VALUE_LEN=${#GET_RESULT}

    success "${secret_name}: OK (${VALUE_LEN} chars, modified: ${MODIFIED})"
    return 0
}

# Check required secrets
header "Required Secrets"
info "These secrets must exist for the platform to function"
echo ""

REQUIRED_FAILURES=0
for secret in "${REQUIRED_SECRETS[@]}"; do
    if ! check_secret "${secret}" "true"; then
        ((REQUIRED_FAILURES++))
    fi
done

# Check optional secrets
if [[ ${#OPTIONAL_SECRETS[@]} -gt 0 ]]; then
    header "Optional Secrets"
    info "These secrets enhance functionality but are not required"
    echo ""

    for secret in "${OPTIONAL_SECRETS[@]}"; do
        check_secret "${secret}" "false" || true
    done
fi

# List all secrets under the prefix
header "All Secrets Under ${SECRET_PREFIX}"

LIST_RESULT=$("${AWS_CLI}" secretsmanager list-secrets \
    --filter "Key=name,Values=${SECRET_PREFIX}" \
    --query 'SecretList[*].{Name:Name,Created:CreatedDate,Modified:LastChangedDate}' \
    --output json 2>&1) || {
    warn "Failed to list secrets"
    LIST_RESULT="[]"
}

SECRET_COUNT=$(echo "${LIST_RESULT}" | jq 'length')
if [[ "${SECRET_COUNT}" -eq 0 ]]; then
    warn "No secrets found under ${SECRET_PREFIX}"
else
    info "Found ${SECRET_COUNT} secrets:"
    echo ""
    echo "${LIST_RESULT}" | jq -r '.[] | "  \(.Name)"'
fi

# Summary
header "Summary"

if [[ ${REQUIRED_FAILURES} -gt 0 ]]; then
    error "${REQUIRED_FAILURES} required secret(s) are missing or invalid!"
    echo ""
    info "To create missing secrets:"
    info "  ./scripts/secrets-manager-set.sh <secret-suffix> 'your-value'"
    info "  ./scripts/secrets-manager-set.sh <secret-suffix> --generate"
    echo ""
    exit 1
else
    success "All required secrets are configured and accessible"
fi

echo ""
info "For more details:"
info "  View secret:   ./scripts/secrets-manager-get.sh <secret-name>"
info "  Update secret: ./scripts/secrets-manager-set.sh <secret-name> <value>"
